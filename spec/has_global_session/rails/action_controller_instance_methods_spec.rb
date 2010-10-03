require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

include HasGlobalSession

class StubRequest
  attr_reader :cookies, :params

  def initialize(cookies, params)
    @cookies = cookies
    @params  = params
  end
end

class StubResponse
  def initialize(cookies)
    @cookies = cookies
  end

  def set_cookie(key, hash)
    @cookies[key] = hash[:value]
  end
end

# Stub controller into which we manually wire the HasGlobalSession instance methods.
# Normally this would be accomplished via the "has_global_session" class method of
# ActionController::Base, but we want to avoid the configuration-related madness.
class StubController < ActionController::Base
  include Rails::ActionControllerInstanceMethods

  def initialize(cookies={}, local_session={})
    super()

    self.request  = StubRequest.new(cookies, params)
    self.response = StubResponse.new(cookies)
    self.session  = local_session
  end
end

describe Rails::ActionControllerInstanceMethods do
  include SpecHelper

  before(:all) do
    @keystore = KeyFactory.new
    @keystore.create('authority1', true)
    @keystore.create('authority2', false)

    mock_config('common/integrated', true)
  end

  after(:all) do
    @keystore.destroy
  end

  before(:each) do
    mock_config('common/attributes/signed', ['user'])
    mock_config('common/attributes/insecure', ['favorite_color'])
    mock_config('test/timeout', '60')
    mock_config('test/cookie/name', 'global_session_cookie')
    mock_config('test/cookie/domain', 'localhost')
    mock_config('test/trust', ['authority1'])
    mock_config('test/authority', 'authority1')

    ActionController::Base.global_session_config = mock_config

    @directory        = Directory.new(mock_config, @keystore.dir)
    @original_session = GlobalSession.new(@directory)
    @cookie           = @original_session.to_s

    @controller = StubController.new('global_session_cookie'=>@cookie)
    flexmock(@controller).should_receive(:global_session_create_directory).and_return(@directory)
  end

  after(:each) do
    @keystore.reset
    reset_mock_config
  end

  context :global_session_read_cookie do
    context 'when no cookie is present in the request' do
      before(:each) do
        @controller.request.cookies['global_session_cookie'] = nil
      end

      it 'should initialize a new session' do
        @controller.global_session.should be_nil
        @controller.global_session_read_cookie
        @controller.global_session.should_not be_nil
        @controller.global_session.valid?.should be_true
      end
    end

    context 'when a trusted signature is cached' do
      before(:each) do
        hash = @original_session.signature_digest
        @controller.session_without_global_session[:_session_gbl_valid_sig] = hash
      end

      it 'should not revalidate the signature' do
        flexmock(@directory.authorities['authority1']).should_receive(:public_decrypt).never
        @controller.global_session_read_cookie
      end
    end

    context 'when no trusted signature is cached' do
      before(:each) do
        @controller.session_without_global_session[:_session_gbl_valid_sig] = nil        
      end

      it 'should revalidate the signature' do
        @controller.global_session_read_cookie
      end
    end

    context 'when an exception is raised' do
      it 'should create a new session, update the cookie, and re-raise' do
        flexmock(GlobalSession).should_receive(:new).
                with(@directory, @cookie, nil).and_raise(InvalidSession)
        flexmock(GlobalSession).should_receive(:new).with(@directory)

        flexmock(@controller.request.cookies).should_receive(:[]=)
        lambda {
          @controller.global_session_read_cookie
        }.should raise_error(InvalidSession)        
        @controller.global_session.id.should_not eql(@original_session.id)
      end
    end
  end

  context :global_session_update_cookie do
    before(:each) do
      @mock_cookies = flexmock('cookie store')
      @mock_cookies.should_receive(:[]).with('global_session_cookie').and_return(@cookie)
      flexmock(@controller).should_receive(:cookies).and_return(@mock_cookies)
    end

    context 'when the configuration specifies a cookie domain' do
      before(:each) do
        mock_config('test/cookie/domain', 'realhost.com')
      end

      it 'should set cookies with the domain specified in the configuraiton' do
        @mock_cookies.should_receive(:[]=).with('global_session_cookie',
                      {:value=>nil, :domain=>'realhost.com', :expires=>Time.at(0)}).once

        @controller.global_session_update_cookie
      end
    end
    context 'when the configuration does not specify a cookie domain' do
      before(:each) do
        mock_config('test/cookie/domain', nil)
      end

      it 'should use the server name associated with the HTTP request' do
        server_name = 'localtesthost.somewhere.local'
        env = flexmock('Request environment')
        env.should_receive(:[]).with('SERVER_NAME').and_return(server_name)
        flexmock(@controller.request).should_receive(:env).and_return(env)        

        @mock_cookies.should_receive(:[]=).with('global_session_cookie',
                                                {:value=>nil, :domain=>server_name, :expires=>Time.at(0)}).once

        @controller.global_session_update_cookie
      end
    end
  end

  context :global_session_auto_renew do
    context 'when auto-renew is disabled' do
      it 'should never renew the cookie' do
        fake_now = Time.at(Time.now.to_i + 55.minutes)
        flexmock(Time).should_receive(:now).and_return(fake_now)
        flexmock(GlobalSession).new_instances.should_receive(:renew!).never
        @controller.global_session_read_cookie
        @controller.global_session_auto_renew
      end
    end

    context 'when auto-renew is enabled' do
      before(:each) do
        mock_config('test/renew', '15')
      end

      it 'should not renew the cookie if not needed' do
        @controller.global_session_read_cookie
        @controller.global_session_auto_renew
        @controller.global_session.expired_at.should be_close(@original_session.expired_at, 1)
      end

      it 'should renew the cookie if needed' do
        fake_now = Time.at(Time.now.to_i + 55.minutes)
        flexmock(Time).should_receive(:now).and_return(fake_now)
        new_expired_at = Time.at(Time.now.to_i + 60.minutes)

        @controller.global_session_read_cookie
        @controller.global_session_auto_renew
        @controller.global_session.expired_at.should be_close(new_expired_at, 1)
      end
    end
  end

  context :session_with_global_session do
    context 'when no global session has been instantiated yet' do
      before(:each) do
        @controller.global_session.should be_nil
      end

      it 'should return the Rails session' do
        flexmock(@controller).should_receive(:session_without_global_session).and_return('local session')
        @controller.session.should == 'local session'
      end
    end
    context 'when a global session has been instantiated' do
      before(:each) do
        @controller.global_session_read_cookie
      end

      it 'should return an integrated session' do
        IntegratedSession.should === @controller.session
      end
    end
    context 'when the global session has been reset' do
      before(:each) do
        @controller.global_session_read_cookie
        @old_integrated_session = @controller.session
        IntegratedSession.should === @old_integrated_session
        @controller.instance_variable_set(:@global_session, 'new global session')
      end

      it 'should return a fresh integrated session' do
        @controller.session.should_not == @old_integrated_session
      end
    end
    context 'when the local session has been reset' do
      before(:each) do
        @controller.global_session_read_cookie
        @old_integrated_session = @controller.session
        IntegratedSession.should === @old_integrated_session
        @controller.session = 'new local session'
      end

      it 'should return a fresh integrated session' do
        @controller.session.should_not == @old_integrated_session
      end
    end
  end
end
