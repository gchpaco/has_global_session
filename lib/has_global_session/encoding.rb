module HasGlobalSession
  module Encoding
    class JSON
      def self.load(json)
        ::JSON.load(json)
      end

      def self.dump(object)
        return object.to_json
      end
    end

    # Implements URL encoding, but without newlines, and using '-' and '_' as
    # the 62nd and 63rd symbol instead of '+' and '/'. This makes for encoded
    # values that can be easily stored in a cookie; however, they cannot
    # be used in a URL query string without URL-escaping them since they
    # will contain '=' characters.
    #
    # This scheme is almost identical to the scheme "Base 64 Encoding with URL
    # and Filename Safe Alphabet," described in RFC4648, with the exception that
    # this scheme preserves the '=' padding characters due to limitations of
    # Ruby's built-in base64 encoding routines.
    class Base64Cookie
      def self.load(string)
        tr = string.tr('-_', '+/')
        return tr.unpack('m')[0]
      end
      
      def self.dump(object)
        raw = [object].pack('m')
        raw.tr!('+/', '-_')
        raw.gsub!("\n", '')
        return raw
      end
    end
  end
end
