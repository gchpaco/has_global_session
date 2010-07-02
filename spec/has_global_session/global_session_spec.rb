require File.expand_path(File.join(File.dirname(__FILE__), '..' , 'spec_helper'))

include HasGlobalSession

describe GlobalSession do
  include SpecHelper

  before(:all) do
    @keystore = KeyFactory.new
    @keystore.create('authority1', true)
    @keystore.create('authority2', false)
  end

  after(:all) do
    @keystore.destroy
  end

  before(:each) do
    mock_config('common/attributes/signed', ['user'])
    mock_config('common/attributes/insecure', ['favorite_color'])
    mock_config('test/timeout', '60')
  end

  after(:each) do
    @keystore.reset
    reset_mock_config
  end


  context :load_from_cookie do
    before(:each) do
      mock_config('test/trust', ['authority1'])
      mock_config('test/authority', 'authority1')
      @directory        = Directory.new(@keystore.dir)
      @original_session = GlobalSession.new(@directory)
      @cookie           = @original_session.to_s
    end

    context 'when everything is copascetic' do
      it 'should succeed' do
        GlobalSession.should === GlobalSession.new(@directory, @cookie)
      end
    end

    context 'when an insecure attribute has changed' do
      before do
        zbin = Encoding::Base64Cookie.load(@cookie)
        json = Zlib::Inflate.inflate(zbin)
        hash = Encoding::JSON.load(json)
        hash['dx'] = {'favorite_color' => 'blue'}
        json = Encoding::JSON.dump(hash)
        zbin = Zlib::Deflate.deflate(json, Zlib::BEST_COMPRESSION)
        @cookie = Encoding::Base64Cookie.dump(zbin)        
      end
      it 'should succeed' do
        GlobalSession.should === GlobalSession.new(@directory, @cookie)
      end
    end

    context 'when a secure attribute has been tampered with' do
      before do
        zbin = Encoding::Base64Cookie.load(@cookie)
        json = Zlib::Inflate.inflate(zbin)
        hash = Encoding::JSON.load(json)
        hash['ds'] = {'evil_haxor' => 'mwahaha'}
        json = Encoding::JSON.dump(hash)
        zbin = Zlib::Deflate.deflate(json, Zlib::BEST_COMPRESSION)
        @cookie = Encoding::Base64Cookie.dump(zbin)        
      end
      it 'should raise SecurityError' do
        lambda {
          GlobalSession.new(@directory, @cookie)
        }.should raise_error(SecurityError)
      end
    end

    context 'when the signer is not trusted' do
      before do
        mock_config('test/trust', ['authority1'])
        mock_config('test/authority', 'authority1')
        @directory2 = Directory.new(@keystore.dir)
        @cookie = GlobalSession.new(@directory2).to_s
        mock_config('test/trust', ['authority2'])
        mock_config('test/authority', nil)        
      end
      it 'should raise SecurityError' do
        lambda {
          GlobalSession.new(@directory, @cookie)
        }.should raise_error(SecurityError)
      end
    end

    context 'when the session is expired' do
      before do
        fake_now = Time.at(Time.now.to_i + 1.days)
        flexmock(Time).should_receive(:now).and_return(fake_now)        
      end
      it 'should raise ExpiredSession' do
        lambda {
          GlobalSession.new(@directory, @cookie)
        }.should raise_error(ExpiredSession)
      end
    end
  end
end