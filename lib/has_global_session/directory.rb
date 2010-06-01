module HasGlobalSession
  class Directory
    attr_reader :authorities, :my_private_key, :my_authority_name

    def initialize(keystore_directory)
      certs = Dir[File.join(keystore_directory, '*.pub')]
      keys  = Dir[File.join(keystore_directory, '*.key')]

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
end