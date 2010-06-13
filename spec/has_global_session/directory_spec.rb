require File.expand_path(File.join(File.dirname(__FILE__), '..' , 'spec_helper'))

describe HasGlobalSession::Directory do
  before(:each) do
    @keystore_dir = File.join( Dir.tmpdir, "#{File.basename(__FILE__)}_#{Process.pid}_#{rand(2**32)}" )
    FileUtils.mkdir_p(@keystore_dir)
  end

  after(:each) do
    FileUtils.rm_rf(@keystore_dir)
  end

  def create_keypair(name, write_private)
    new_key     = OpenSSL::PKey::RSA.generate( 256 )
    new_public  = new_key.public_key.to_pem
    new_private = new_key.to_pem
    File.open(File.join(@keystore_dir, "#{name}.pub")) { |f| f.puts new_public }
    File.open(File.join(@keystore_dir, "#{name}.key")) { |f| f.puts new_key }
  end

  describe :initialize do
    context 'when a local authority is configured' do
      before(:each) do
        @authority_name = "authority#{rand(2**16)}"
        flexmock(Configuration).should_receive(:[]).with('authority').and_return(@authority_name)
      end

      context 'and keystore contains no private keys' do
        create_keypair(@authority_name, true, false)
        Directory.new(@keystore_dir).should_raise(ConfigurationError)
      end

      context 'and keystore contains an incorrectly-named private key' do
        create_keypair('wrong_name', true, true)
        Directory.new(@keystore_dir).should_raise(ConfigurationError)
      end

      context 'and keystore contains two private keys' do
        create_keypair(@authority_name, true, true)
        create_keypair('wrong_name', true, true)
        Directory.new(@keystore_dir).should_raise(ConfigurationError)

      end

      context 'and keystore contains a correctly-named private key' do
        create_keypair(@authority_name, true, true)
        Directory.new(@keystore_dir).should_raise(ConfigurationError).should_return(Directory)
      end
    end
  end
end