require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'spec_helper'))

include HasGlobalSession

class StubController
  def initialize(cookies={}, local_session={})
    @cookies = cookies
    @session = local_session
  end

  attr_reader :global_session, :cookies, :session

  def self.before_filter(sym); true; end

  def self.after_filter(sym); true; end
end

describe Rails::ActionControllerInstanceMethods do
  include SpecHelper

  before(:all) do
    @keystore = KeyFactory.new
    @keystore.create('authority1', true)
    @keystore.create('authority2', false)

    mock_config('common/integrated', true)

    class StubController
      include Rails::ActionControllerInstanceMethods
    end
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
    @directory        = Directory.new(@keystore.dir)
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
    context 'when an exception is raised' do
      it 'should create a new session, update the cookie, and re-raise' do
        flexmock(GlobalSession).should_receive(:new).
                with(@directory, @cookie).and_raise(InvalidSession)
        flexmock(GlobalSession).should_receive(:new).with(@directory)

        flexmock(@controller.cookies).should_receive(:[]=)
        lambda {
          @controller.global_session_read_cookie
        }.should raise_error(InvalidSession)        
        @controller.global_session.id.should_not eql(@original_session.id)
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
      it 'should return the Rails session'
    end
    context 'when a global session has been instantiated' do
      it 'should return an integrated session'
    end
    context 'when the global session ID has changed' do
      it 'should return a fresh integrated session'
    end
  end
end
