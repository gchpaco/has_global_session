basedir = File.dirname(__FILE__)
require File.join(basedir, 'has_global_session', 'configuration')
require File.join(basedir, 'has_global_session', 'directory')
require File.join(basedir, 'has_global_session', 'session')

module HasGlobalSession
  module ActionControllerInstanceMethods
    def global_session
      return @global_session if @global_session

      begin
        cookie = cookies[Configuration['cookie']['name']]
        if cookie && (cookie.length > 0)
          #unserialize the global session from the cookie
          @global_session = Session.new(Directory.new, cookie)
        else
          #initialize a new global session
          @global_session = Session.new(Directory.new)
        end
      rescue Exception => e
        cookies.delete Configuration['cookie']['name']
        raise e
      end
    end

    def global_session_update_cookie
      if @global_session
        if @global_session.expired?
          options = {:value   => nil,
                     :domain  => Configuration['cookie']['domain'],
                     :expires => Time.at(0)}
        else
          options = {:value   => @global_session.to_s,
                     :domain  => Configuration['cookie']['domain'],
                     :expires => @global_session.expires_at}
        end

        cookies[Configuration['cookie']['name']] = options
      end
    end
  end
end
