module HasGlobalSession
  module ActionControllerInstanceMethods
    def global_session
      return @global_session if @global_session

      begin
        cookie = cookies[Configuration['cookie']['name']]
        directory = Directory.new(File.join(RAILS_ROOT, 'config', 'authorities'))

        begin
          #unserialize the global session from the cookie, or
          #initialize a new global session if cookie == nil
          @global_session = GlobalSession.new(directory, cookie)
        rescue SessionExpired
          #if the cookie is present but expired, silently
          #initialize a new global session
          @global_session = GlobalSession.new(directory)
        end
      rescue Exception => e
        cookies.delete Configuration['cookie']['name']
        raise e
      end
    end

    if Configuration['integrated']
      def session
        @integrated_session ||= IntegratedSession.new(super, global_session)
        return @integrated_session
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
