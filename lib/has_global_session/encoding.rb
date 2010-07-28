module HasGlobalSession
  # Various encoding (not encryption!) techniques used by the global session plugin.
  #
  module Encoding
    # JSON serializer, used to serialize Hash objects in a form suitable
    # for stuffing into a cookie.
    #
    class JSON
      # Unserialize JSON to Hash.
      #
      # === Parameters
      # json(String):: A well-formed JSON document
      #
      # === Return
      # value(Hash):: An unserialized Ruby Hash
      def self.load(json)
        ::JSON.load(json)
      end

      # Serialize Hash to JSON document.
      #
      # === Parameters
      # value(Hash):: The hash to be serialized
      #
      # === Return
      # json(String):: A JSON-serialized representation of +value+
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
      # Decode a B64cookie-encoded string.
      #
      # === Parameters
      # encoded(String):: The encoded string
      #
      # === Return
      # decoded(String):: The decoded result, which may contain nonprintable bytes
      def self.load(string)
        tr = string.tr('-_', '+/')
        return tr.unpack('m')[0]
      end
      
      # Encode a Ruby (ASCII or binary) string.
      #
      # === Parameters
      # decoded(String):: The raw string to be encoded
      #
      # === Return
      # encoded(String):: The B64cookie-encoded result.
      def self.dump(object)
        raw = [object].pack('m')
        raw.tr!('+/', '-_')
        raw.gsub!("\n", '')
        return raw
      end
    end
  end
end
