Updater
=======

Updater is a background job queue processor.
It works a bit like delayed_job or rescue,
processing jobs in the background to allow user facing processes to stay responsive.
It also allow jobs to be scheduled and run at a particular time.
It is intended to work with a number of different ORM layers,
but at the moment only DataMapper is implemented.
Native support for MongoDB and ActiveRecord are planed.
Get it on GemCutter with `gem install updater`.

Main Features
-------------

* Handles both immediate and time delayed jobs
* Intelligent Automatic Scaling
* Does not poll the database
* Uses minimal resources when not under load
* Flexible Job Chaining allows for intelligent error handling and rescheduling
* Powerful configuration with intelligent defaults
* Comes with `rake` tasks

These feature are as of ver 0.9.1.  See the change log for addational features

Use Cases
---------

Web based applications face two restrictions on their functionality
as it pertains to data processing tasks.
First, the application will only run code in response to a user request.
Updater handles the case of actions or events that need to be triggered
without a request coming in to the web application.
Second, web applications, particularly those under heavy load,
need to handle as many request as possible in a given time frame.
Updater allows data processing and communication tasks
to happen outside of the request response cycle
and makes it possible to move these tasks onto dedicated hardware

Updater is also useful for circumstances where code needs to be run
in a time dependent fashion,
particularly when these events need to be closely controlled by the code.

Updater is not a replacement for `cron`.
Jobs that are regular and repeating can be run
more consistently and with fewer resources with `cron`.
Updater should be considered when the application generates
a large number of one time events,
and/or the events need to be regularly manipulated bu the application.

Updater is also not the optimal solution if the only goal
is to offload large numbers of immediate tasks.
For this the author recommends 
[resque](http://github.com/defunkt/resque)
by Chris Wanstrath.

Resque lacks a number of Updater's more powerful features,
and as of this writing we are not aware of any ability in resque
to set the time the job is run.
But rescue does offer much higher potential throughput, and
a more robust queue structure backed by the Redis key-value store.

Using Updater
=============

Initial Installation
--------------------

Updater comes packaged as a gem and is published on GemCutter.
Get the latest version with `gem install updater`

Setup
-----

Updater is not complex to use but it does, of necessity, have a number of *moving parts*.
In order to use updater successfully two tasks must be accomplished:
your application (referred to as the client) must be able to add jobs to the queue,
and a separate process (the server) must be setup and run 
which will preform the actions specified in those jobs.

Jobs are stored in a data store that is shared between client and server.
Usually this data store will be a table in your database.
Other data stores are possible, but require significantly configuration.
Updater is designed to have a minimal impact on the load of the data store,
and it therefore should be a reasonable solution for most applications. 