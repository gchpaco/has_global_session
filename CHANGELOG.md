= 0.8.10 (2010-07-01)

* Don't raise ExpiredSession in Rails before-filter (it causes weird edge cases).
* Ensure IntegratedSession never has a stale GlobalSession.

= 0.8.9 (2010-06-29)

* ExpiredSession exception for the error-handling convenience of the application.
* Ensure we clear out the cookie when it throws an exception while trying to write it back. 

= 0.8.7 (2010-06-28)

* Stop using custom exception-reporting; rely on Rails' rescue_action_* instead
* Use a before-filter to load the global session instead of loading on demand;
  prevent ourselves from throwing exceptions before Rails has even had a chance
  to initialize its error-handling behavior.
* Override ActionController::Base#session using alias_method_chain instead of
  class-to-module inheritance; helps readability of code.

= 0.8.6 (2010-06-17)

* Add auto-renew of sessions that are going to expire soon
* Add some test coverage (but not very extensive!) for GlobalSession

= 0.8.5 (2010-06-16)

* Bug fix in GlobalSession (calling Directory method with wrong number of params)
* Undo some stupid decisions made in 0.8.4

= 0.8.4 (2010-06-15)

* Change #expires_at to #expired_at
* Change some Directory callbacks to enable more reliable single sign-out for
  custom Directory implementations.

= 0.8.3 (2010-06-11)

* Explicitly track local authority name in config (avoid misconfiguration errors)
* Change cookie encoding to single-line, URL-friendly Base64
* Better reliability, error-handling and exception reporting
