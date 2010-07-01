module HasGlobalSession
  class IntegratedSession
    attr_reader :local, :global
    
    def initialize(local, global)
      @local = local
      @global = global
    end

    def [](key)
      key = key.to_s
      if @global.supports_key?(key)
        @global[key]
      else
        @local[key]
      end
    end

    def []=(key, value)
      key = key.to_s
      if @global.supports_key?(key)
        @global[key] = value
      else
        @local[key] = value
      end
    end

    def has_key?(key)
      key = key.to_s
      @global.has_key(key) || @local.has_key?(key)
    end

    def keys
      @global.keys + @local.keys
    end

    def values
      @global.values + @local.values
    end

    def each_pair(&block)
      @global.each_pair(&block)
      @local.each_pair(&block)
    end

    def method_missing(meth, *args)
      if @global.respond_to?(meth)
        return @global.send(meth, *args)
      elsif @local.respond_to?(meth)
        return @local.send(meth, *args)
      else
        super
      end
    end
  end
end