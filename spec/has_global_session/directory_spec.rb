require File.expand_path(File.join(File.dirname(__FILE__), '..' , 'spec_helper'))

require 'tempfile'

include HasGlobalSession

describe HasGlobalSession::Directory do

  before(:each) do
    @keystore = Keystore.new
  end
  
  after(:each) do
    @keystore.reset
  end

  after(:all) do
    @keystore.destroy
  end
  
  describe :initialize do
    context 'when a local authority is configured' do
      before(:each) do
        @authority_name = "authority#{rand(2**16)}"
        flexmock(Configuration).should_receive(:[]).with('authority').and_return(@authority_name)
      end

      context 'and keystore contains no private keys' do
        it 'should raise an error' do
          @keystore.create(@authority_name, false)
          lambda {
            Directory.new(@keystore.dir)
          }.should raise_error(ConfigurationError)
        end
      end

      context 'and keystore contains an incorrectly-named private key' do
        it 'should raise an error' do
          @keystore.create('wrong_name', true)
          lambda {
            Directory.new(@keystore.dir)
          }.should raise_error(ConfigurationError)
        end
      end

      context 'and keystore contains two private keys' do
        it 'should raise an error' do
          @keystore.create(@authority_name, true)
          @keystore.create('wrong_name', true)

          lambda {
            Directory.new(@keystore.dir)
          }.should raise_error(ConfigurationError)
        end
      end

      context 'and keystore contains a correctly-named private key' do
        it 'should succeed' do
          @keystore.create(@authority_name, true)
          Directory.should === Directory.new(@keystore.dir)
        end
      end
    end
  end
end