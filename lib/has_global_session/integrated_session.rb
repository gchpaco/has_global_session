module HasGlobalSession
  class IntegratedSession
    def initialize(local_session, global_session)
      @local_session = local_session
      @global_session = global_session
    end

    def [](key)
      key = key.to_s
      if @global_session.supports_key?(key)
        @global_session[key]
      else
        @local_session[key]
      end
    end

    def []=(key, value)
      key = key.to_s
      if @global_session.supports_key?(key)
        @global_session[key] = value
      else
        @local_session[key] = value
      end
    end

    def has_key?(key)
      key = key.to_s
      @global_session.has_key(key) || @local_session.has_key?(key)
    end

    def keys
      @global_session.keys + @local_session.keys
    end

    def values
      @global_session.values + @local_session.values
    end

    def each_pair(&block)
      @global_session.each_pair(&block)
      @local_session.each_pair(&block)
    end
  end
end