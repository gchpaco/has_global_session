require 'set'
require 'zlib'

module HasGlobalSession
  class Session
    @@signed   = nil
    @@insecure = nil

    attr_reader :id, :authority, :created_at, :expires_at

    def initialize(directory, cookie=nil)
      @@signed   ||= Set.new((Configuration['attributes']['signed'] rescue []))
      @@insecure ||= Set.new((Configuration['attributes']['insecure'] rescue []))

      @directory = directory

      if cookie
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
          raise SecurityError, "Signature mismatch on global session hash; tampering suspected"
        end
      else
        @signed          = {}
        @insecure        = {}
        @id              = rand(2**160).to_s(16).ljust(40, '0')    #TODO better randomness
        @created_at      = Time.now.utc
        @expires_at      = 2.hours.from_now.utc #TODO configurable
        @authority       = @directory.my_authority_name
        @dirty_secure    = true
      end
    end

    def expired?
      (@expires_at <= Time.now)
    end

    def expire!
      @expires_at = Time.at(0)
    end

    def to_s
      hash = {'id'=>@id,
              'tc'=>@created_at.to_i, 'te'=>@expires_at.to_i,
              'ds'=>@signed, 'dx'=>@insecure}

      if @signature && !@dirty_secure
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
      json = ActiveSupport::JSON.encode(hash)
      zbin = Zlib::Deflate.deflate(json, Zlib::BEST_COMPRESSION)
      return Base64.encode64(zbin)
    end

    def [](key)
      @signed[key] || @insecure[key]
    end

    def []=(key, value)
      if @@signed.include?(key)
        unless @directory.my_private_key && @directory.my_authority_name
          raise StandardError, 'Cannot change secure session attributes; we are not an authority'
        end

        @signed[key]  = value
        @dirty_secure = true
      elsif @@insecure.include?(key)
        @insecure[key] = value
      else
        raise ArgumentError, "Key '#{key}' is not specified in global session configuration"
      end
    end

    def keys
      (@secure.keys + @insecure.keys)
    end

    def values
      (@secure.values + @insecure.values)
    end

    def each_pair(&block)
      @secure.each_pair(&block)
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