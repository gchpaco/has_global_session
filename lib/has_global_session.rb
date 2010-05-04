require 'json'
require 'set'
require 'zlib'

module HasGlobalSession
  module Configuration
    def self.[](key)
      return @config[RAILS_ENV][key] if @config
      @config ||= YAML.load(File.read(File.join(RAILS_ROOT, 'config', 'global_session.yml')))
      validate
      return @config[RAILS_ENV][key]
    end

    def self.validate
      #TODO
    end
  end
  
  class Directory
    attr_reader :authorities, :my_private_key, :my_authority_name
    
    def initialize
      dir   = File.join(RAILS_ROOT, 'config', 'authorities')
      certs = Dir[File.join(dir, '*.pub')]
      keys  = Dir[File.join(dir, '*.key')]

      @authorities = {}
      certs.each do |cert_file|
        basename = File.basename(cert_file)
        authority = basename[0...(basename.rindex('.'))] #chop trailing .ext
        @authorities[authority] = OpenSSL::PKey::RSA.new(File.read(cert_file))
        raise TypeError, "Expected #{basename} to contain an RSA public key" unless @authorities[authority].public?
      end

      raise ArgumentError, "Excepted 0 or 1 key files, found #{keys.size}" if ![0, 1].include?(keys.size)
      if (key_file = keys[0])
        basename = File.basename(key_file)
        @my_private_key  = OpenSSL::PKey::RSA.new(File.read(key_file))
        raise TypeError, "Expected #{basename} to contain an RSA private key" unless @my_private_key.private?
        @my_authority_name = basename[0...(basename.rindex('.'))] #chop trailing .ext
      end
    end
  end
  
  class GlobalSession
    @@signed   = nil
    @@insecure = nil

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
        got      = @directory.authorities[@authority].public_decrypt(Base64.decode64(@signature))
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
        @dirty_signature = true
      end
    end

    def [](key)
      @signed[key] || @insecure[key]
    end

    def []=(key, value)
      if @@signed.include?(key)
        unless @directory.my_private_key && @directory.my_authority_name
          raise StandardError, 'Cannot change secure session attributes; we are not an authority'
        end

        @signed[key] = value
        @dirty_signature = true
      elsif @@insecure.include?(key)
        @insecure[key] = value
      else
        raise ArgumentError, "Key '#{key}' is not specified in global session configuration"
      end
    end

    def to_s
      hash = {'id'=>@id,
              'tc'=>@created_at.to_i, 'te'=>@expires_at.to_i,
              'ds'=>@signed, 'dx'=>@insecure}

      if @signature && !@dirty_signature
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

  module InstanceMethods
    def global_session
      return @global_session if @global_session

      begin
        cookie = cookies[Configuration['cookie']['name']]
        @global_session = GlobalSession.new(Directory.new, cookie) if cookie && (cookie.length > 0)
        return @global_session
      rescue Exception => e
        cookies.delete Configuration['cookie']['name']
        raise e
      end
    end

    def global_session_update
      cookies[Configuration['cookie']['name']] = @global_session.to_s
    end
  end
end
