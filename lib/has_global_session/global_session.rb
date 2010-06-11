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
        load_from_cookie(cookie)
      elsif @directory.my_authority_name
        create_from_scratch
      else
        create_invalid
      end
    end

    def valid?
      @id && (@expires_at > Time.now) && ! @directory.invalidated_session?(@id)
    end

    def to_s
      if @cookie && !@dirty_insecure && !@dirty_secure
        #use cached cookie if nothing has changed
        return @cookie
      end

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
      json = hash.to_json
      zbin = Zlib::Deflate.deflate(json, Zlib::BEST_COMPRESSION)
      return Base64.encode64(zbin)
    end

    def supports_key?(key)
      @schema_signed.include?(key) || @schema_insecure.include?(key)
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

    def [](key)
      @signed[key] || @insecure[key]
    end

    def []=(key, value)
      raise InvalidSession unless valid?
      #Ensure that the value is serializable (will raise if not)
      canonicalize(value)

      if @schema_signed.include?(key)
        authority_check
        @signed[key]  = value
        @dirty_secure = true
      elsif @schema_insecure.include?(key)
        @insecure[key] = value
        @dirty_insecure = true
      else
        raise ArgumentError, "Attribute '#{key}' is not specified in global session configuration"
      end
    end

    def expire!
      authority_check
      @expires_at = Time.at(0)
      @dirty_secure = true
    end

    def renew!
      authority_check
      @expires_at = Configuration['timeout'].to_i.minutes.from_now.utc || 1.hours.from_now.utc
      @dirty_secure = true
    end

    private

    def logger
      Configuration.logger
    end

    def authority_check
      unless @directory.my_authority_name
        raise NoAuthority, 'Cannot change secure session attributes; we are not an authority'
      end      
    end

    def digest(input)
      begin
        canonical = canonicalize(input).to_json
      rescue UnserializableType => e
        logger.error "Global session hash contains unserializable objects: #{input.inspect}"
        raise e
      end
      return Digest::SHA1.new().update(canonical).hexdigest
    end

    def canonicalize(input)
      case input
        when Hash
          output = Array.new
          ordered_keys = input.keys.sort
          ordered_keys.each do |key|
            output << [ canonicalize(key), canonicalize(input[key]) ]
          end
        when Array
          output = input.collect { |x| canonicalize(x) }
        when Numeric, String, NilClass
          output = input
        else
          raise UnserializableType, "Objects of type #{input.class.name} cannot be serialized in the global session"
      end

      return output
    end

    def load_from_cookie(cookie)
      zbin = Base64.decode64(cookie)
      json = Zlib::Inflate.inflate(zbin)
      hash = JSON.load(json)

      id         = hash['id']
      created_at = Time.at(hash['tc'].to_i)
      expires_at = Time.at(hash['te'].to_i)
      signed     = hash['ds']
      insecure   = hash['dx']
      signature  = hash['s']
      authority  = hash['a']

      #Check signature
      hash.delete('s')
      expected = digest(hash)
      signer   = @directory.authorities[authority]
      raise SecurityError, "Unknown signing authority #{authority}" unless signer
      got      = signer.public_decrypt(Base64.decode64(signature))
      unless (got == expected)
        raise SecurityError, "Signature mismatch on global session cookie; tampering suspected"
      end

      #Check trust in signing authority
      unless @directory.trusted_authority?(authority)
        raise SecurityError, "Global sessions created by #{authority} are not trusted"
      end

      #Check expiration
      if expires_at <= Time.now || @directory.invalidated_session?(id)
        raise ExpiredSession, "Global session cookie has expired"
      end

      #If all validation stuff passed, assign our instance variables.
      @id         = id
      @created_at = created_at
      @expires_at = expires_at
      @signed     = signed
      @insecure   = insecure
      @authority  = authority
      @signature  = signature
      @cookie     = cookie
    end

    def create_from_scratch
      authority_check

      @signed          = {}
      @insecure        = {}
      @created_at      = Time.now.utc
      @authority       = @directory.my_authority_name

      if defined?(::UUIDTools) # UUIDTools v2
        @id = ::UUIDTools::UUID.timestamp_create.to_s
      elsif defined?(::UUID)   # UUIDTools v1
        @id = ::UUID.timestamp_create.to_s
      else
        raise TypeError, "Neither UUIDTools nor UUID defined; unsupported UUIDTools version?"
      end

      renew!
    end

    def create_invalid
      @id         = nil
      @created_at = Time.now
      @expires_at = created_at
      @signed     = {}
      @insecure   = {}
      @authority  = nil
    end
  end  
end
