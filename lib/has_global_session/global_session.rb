# Standard library dependencies
require 'set'
require 'zlib'

# Gem dependencies
require 'uuidtools'

module HasGlobalSession 
  class GlobalSession
    attr_reader :id, :authority, :created_at, :expired_at, :directory

    def initialize(directory, cookie=nil, valid_signature_digest=nil)
      @schema_signed   = Set.new((Configuration['attributes']['signed']))
      @schema_insecure = Set.new((Configuration['attributes']['insecure']))
      @directory       = directory

      if cookie
        load_from_cookie(cookie, valid_signature_digest)
      elsif @directory.local_authority_name
        create_from_scratch
      else
        create_invalid
      end
    end

    def valid?
      @directory.valid_session?(@id, @expired_at)
    end

    def to_s
      if @cookie && !@dirty_insecure && !@dirty_secure
        #use cached cookie if nothing has changed
        return @cookie
      end

      hash = {'id'=>@id,
              'tc'=>@created_at.to_i, 'te'=>@expired_at.to_i,
              'ds'=>@signed}

      if @signature && !@dirty_secure
        #use cached signature unless we've changed secure state
        authority = @authority
      else
        authority_check
        authority = @directory.local_authority_name
        hash['a'] = authority
        digest    = canonical_digest(hash)
        @signature = Encoding::Base64Cookie.dump(@directory.private_key.private_encrypt(digest))
      end

      hash['dx'] = @insecure
      hash['s']  = @signature
      hash['a']  = authority
      
      json = Encoding::JSON.dump(hash)
      zbin = Zlib::Deflate.deflate(json, Zlib::BEST_COMPRESSION)
      return Encoding::Base64Cookie.dump(zbin)
    end

    def supports_key?(key)
      @schema_signed.include?(key) || @schema_insecure.include?(key)
    end

    def has_key?(key)
      @signed.has_key(key) || @insecure.has_key?(key)
    end

    def signature_digest
      @signature ? digest(@signature) : nil
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

    def invalidate!
      @directory.report_invalid_session(@id, @expired_at)
    end

    def renew!
      authority_check
      @expired_at = Configuration['timeout'].to_i.minutes.from_now.utc
      @dirty_secure = true
    end

    private

    def authority_check
      unless @directory.local_authority_name
        raise NoAuthority, 'Cannot change secure session attributes; we are not an authority'
      end      
    end

    def canonical_digest(input)
      canonical = Encoding::JSON.dump(canonicalize(input))
      return digest(canonical)
    end

    def digest(input)
      return Digest::SHA1.new().update(input).hexdigest
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

    def load_from_cookie(cookie, valid_signature_digest)
      zbin = Encoding::Base64Cookie.load(cookie)
      json = Zlib::Inflate.inflate(zbin)
      hash = Encoding::JSON.load(json)

      id         = hash['id']
      authority  = hash['a']
      created_at = Time.at(hash['tc'].to_i).utc
      expired_at = Time.at(hash['te'].to_i).utc
      signed     = hash['ds']
      insecure   = hash.delete('dx')
      signature  = hash.delete('s')

      unless valid_signature_digest == digest(signature)
        #Check signature
        expected = canonical_digest(hash)
        signer   = @directory.authorities[authority]
        raise SecurityError, "Unknown signing authority #{authority}" unless signer
        got      = signer.public_decrypt(Encoding::Base64Cookie.load(signature))
        unless (got == expected)
          raise SecurityError, "Signature mismatch on global session cookie; tampering suspected"
        end
      end
      
      #Check trust in signing authority
      unless @directory.trusted_authority?(authority)
        raise SecurityError, "Global sessions signed by #{authority} are not trusted"
      end

      #Check expiration
      unless expired_at > Time.now.utc
        raise ExpiredSession, "Session expired at #{expired_at}"        
      end

      #Check other validity (delegate to directory)
      unless @directory.valid_session?(id, expired_at)
        raise InvalidSession, "Global session has been invalidated"
      end

      #If all validation stuff passed, assign our instance variables.
      @id         = id
      @authority  = authority
      @created_at = created_at
      @expired_at = expired_at
      @signed     = signed
      @insecure   = insecure
      @signature  = signature
      @cookie     = cookie
    end

    def create_from_scratch
      authority_check

      @signed          = {}
      @insecure        = {}
      @created_at      = Time.now.utc
      @authority       = @directory.local_authority_name

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
      @created_at = Time.now.utc
      @expired_at = created_at
      @signed     = {}
      @insecure   = {}
      @authority  = nil
    end
  end  
end
