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
    attr_reader :authorities, :my_key, :my_name
    
    def initialize
      dir   = File.join(RAILS_ROOT, 'config', 'authorities')
      certs = Dir[File.join(dir, '*.cert')] + Dir[File.join(dir, '*.crt')]
      keys  = Dir[File.join(dir, '*.key')] + Dir[File.join(dir, '*.pvk')]

      @authorities = {}
      certs.each do |cert_file|
        cert_file = File.basename(cert_file)
        authority = cert_file[0..(cert_file.rindex('.'))] #chop trailing .ext
        @authorities[authority] = File.read(cert_file)
      end

      raise ArgumentError, "Excepted 0 or 1 key file, found #{keys.size}" if keys.size > 0
      if keys[0]
        key_file = File.basename(keys[0])
        @my_key  = File.read(keys[0])
        @my_name = key_file[0..(key_file.rindex('.'))] #chop trailing .ext
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
        hash.delete('s')
        #TODO better signature (public-key crypto)
        expected = Digest::SHA1.new().update(ActiveSupport::JSON.encode(canonicalize(hash))).hexdigest
        unless (@signature == expected)
          raise SecurityError, "Signature mismatch on global session hash; tampering suspected"
        end
      else
        @signed     = {}
        @insecure   = {}
        @id         = rand(2**160).to_s(16).ljust(40, '0')    #TODO better randomness 
        @created_at = Time.now.utc
        @expires_at = 2.hours.from_now.utc #TODO configurable
      end
    end

    def [](key)
      @signed[key] || @insecure[key]
    end

    def []=(key, value)
      if @@signed.include?(key)
        @signed[key] = value
        @dirty_signature = true
      elsif @@insecure.include?(key)
        @insecure[key] = value
      else
        raise ArgumentError, "Key '#{key}' is not specified in global session configuration"
      end
    end

    def to_s
      hash = {'id'=>@id, 'tc'=>@created_at.to_i, 'te'=>@expires_at.to_i, 'ds'=>@signed, 'dx'=>@insecure}

      if @signature && !@dirty_signature
        #for speed, use cached signature
        signature = @signature
      else
        #TODO better signature (public-key crypto)
        signature = Digest::SHA1.new().update(ActiveSupport::JSON.encode(canonicalize(hash))).hexdigest
      end
      hash['s'] = signature
      json = ActiveSupport::JSON.encode(hash)
      zbin = Zlib::Deflate.deflate(json, Zlib::BEST_COMPRESSION)
      return Base64.encode64(zbin)
    end

    private

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
      @global_session ||= GlobalSession.new(Directory.new)
    end

    def global_session_initialize()
      begin
        cookie = cookies[Configuration['cookie']['name']]
        @global_session = GlobalSession.new(Directory.new, cookie) if cookie && (cookie.length > 0)
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
