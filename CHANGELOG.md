= 0.8.5 (2010-06-17)

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
