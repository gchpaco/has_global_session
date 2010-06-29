module HasGlobalSession
  class Directory
    attr_reader :authorities, :private_key, :local_authority_name

    def initialize(keystore_directory)
      certs = Dir[File.join(keystore_directory, '*.pub')]
      keys  = Dir[File.join(keystore_directory, '*.key')]
      raise ConfigurationError, "Excepted 0 or 1 key files, found #{keys.size}" unless [0, 1].include?(keys.size)

      @authorities = {}
      certs.each do |cert_file|
        basename = File.basename(cert_file)
        authority = basename[0...(basename.rindex('.'))] #chop trailing .ext
        @authorities[authority] = OpenSSL::PKey::RSA.new(File.read(cert_file))
        raise ConfigurationError, "Expected #{basename} to contain an RSA public key" unless @authorities[authority].public?
      end

      if (authority_name = Configuration['authority'])
        key_file = keys.detect { |kf| kf =~ /#{authority_name}.key$/ }
        raise ConfigurationError, "Key file #{authority_name}.key not found" unless key_file        
        @private_key  = OpenSSL::PKey::RSA.new(File.read(key_file))
        raise ConfigurationError, "Expected #{basename} to contain an RSA private key" unless @private_key.private?
        @local_authority_name = authority_name
      end
    end

    def trusted_authority?(authority)
      Configuration['trust'].include?(authority)
    end

    def valid_session?(uuid, expired_at)
      expired_at > Time.now
    end

    def report_invalid_session(uuid, expired_at)
      true
    end
  end  
end