# Standard library dependencies
require 'set'
require 'zlib'

# Gem dependencies
require 'uuidtools'

module HasGlobalSession 
  class GlobalSession
    attr_reader :id, :authority, :created_at, :expires_at

    def initialize(directory, cookie=nil)
      @schema_signed   = Set.new((Configuration['attributes']['signed'] rescue []))
      @schema_insecure = Set.new((Configuration['attributes']['insecure'] rescue []))
      @directory       = directory

      if cookie
        #User presented us with a cookie; let's decrypt and verify it
        zbin = Base64.decode64(cookie)
        json = Zlib::Inflate.inflate(zbin)
        hash = ActiveSupport::JSON.decode(json)
        @id         = hash['id']
        @created_at = Time.at(hash['tc'].to_i)
        @expires_at = Time.at(hash['te'].to_i)
        @signed     = hash['ds']
        @insecure   = hash['dx']
        @signature  = hash['s']
        @authority  = hash['a']

        hash.delete('s')
        expected = digest(hash)
        signer   = @directory.authorities[@authority]
        raise SecurityError, "Unknown signing authority #{@authority}" unless signer
        got      = signer.public_decrypt(Base64.decode64(@signature))
        unless (got == expected)
          raise SecurityError, "Signature mismatch on global session cookie; tampering suspected"
        end

        unless Configuration['trust'].blank? ||
               @authority = @directory.my_authority_name ||
               Configuration['trust'].include?(@authority)
          raise SecurityError, "Global sessions created by #{@authority} are not trusted"
        end

        if expired? || @directory.invalidated_session?(@id)
          raise ExpiredSession, "Global session cookie has expired"
        end

      else
        @signed          = {}
        @insecure        = {}
        @id              = UUID.timestamp_create.to_s
        @created_at      = Time.now.utc
        @authority       = @directory.my_authority_name
        renew!
      end
    end

    def expired?
      (@expires_at <= Time.now)
    end

    def expire!
      @expires_at = Time.at(0)
      @dirty = true
    end

    def renew!
      @expires_at = Configuration['timeout'].to_i.minutes.from_now.utc || 1.hours.from_now.utc        
      @dirty = true
    end

    def to_s
      hash = {'id'=>@id,
              'tc'=>@created_at.to_i, 'te'=>@expires_at.to_i,
              'ds'=>@signed, 'dx'=>@insecure}

      if @signature && !@dirty
        #use cached signature unless we've changed secure state
        authority = @authority
        signature = @signature
      else
        authority = @directory.my_authority_name
        hash['a'] = authority
        digest    = digest(hash)
        signature = Base64.encode64(@directory.my_private_key.private_encrypt(digest))
      end

      hash['s'] = signature
      hash['a'] = authority
      json = hash.to_json #ActiveSupport::JSON.encode(hash) -- why does this expect Data sometimes?!
      zbin = Zlib::Deflate.deflate(json, Zlib::BEST_COMPRESSION)
      return Base64.encode64(zbin)
    end

    def supports_key?(key)
      @schema_signed.include?(key) || @schema_insecure.include?(key)
    end

    def [](key)
      @signed[key] || @insecure[key]
    end

    def []=(key, value)
      case value
        when String, Numeric, Array
          #no-op
        else
          raise TypeError, "Cannot store values of type #{value.class.name} reliably"
      end

      if @schema_signed.include?(key)
        unless @directory.my_private_key && @directory.my_authority_name
          raise StandardError, 'Cannot change secure session attributes; we are not an authority'
        end

        @signed[key]  = value
        @dirty = true
      elsif @schema_insecure.include?(key)
        @insecure[key] = value
      else
        raise ArgumentError, "Attribute '#{key}' is not specified in global session configuration"
      end
    end

    def has_key?(key)
      @signed.has_key(key) || @insecure.has_key?(key)
    end

    def keys
      @signed.keys + @insecure.keys
    end

    def values
      @signed.values + @insecure.values
    end

    def each_pair(&block)
      @signed.each_pair(&block)
      @insecure.each_pair(&block)
    end

    private

    def digest(input)
      canonical = ActiveSupport::JSON.encode(canonicalize(input))
      return Digest::SHA1.new().update(canonical).hexdigest
    end

    def canonicalize(input)
      case input
        when Hash
          output = ActiveSupport::OrderedHash.new
          ordered_keys = input.keys.sort
          ordered_keys.each do |key|
            output[canonicalize(key)] = canonicalize(input[key])
          end
        when Array
          output = input.collect { |x| canonicalize(x) }
        when Numeric, String, ActiveSupport::OrderedHash
          output = input
        else
          raise TypeError, "Objects of type #{input.class.name} cannot be serialized in the global session"
      end

      return output
    end
  end  
end