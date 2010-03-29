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

Consepts
--------

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
(For a discussion of when this is not a reasonable solution see 
[the Rescue Blog Post](http://github.com/blog/542-introducing-resque))

Updater is very flexible about what can be run in as a background job.
The Job will call a single method on either a Class or an instance.
The method must be public.
Any arguments can be passed to the method so long as the can be marshaled.
It is important to keep in mind that the job will be run in a completely separate process.
Any global state will have to be recreated,
and data must be persisted in some form in order to be seen by the client.
For web applications this is usually not an issue.

Calling a class method is fairly strait forward,
but calling a method on in instance take a little more work.
Instances must be somehow persisted in the client
then reinstantiated on the worker process.
The assumption is that this will be don through the ORM and data store.
Each ORM adapter in Updater lists a defaults methods 
for retrieving particular instances from the data store.
When an instance is scheduled as the target of a job,
its class and id will be stored in the `updates` table.
When the job is run it will first use the it to pull the instance out of the data store,
then call the appropriate method on that instance.

Client Setup
------------

The client application needs to do two things to be able to effectively schedule jobs:
1) require the `updater` library, and
2) call the `Updater::Setup.client_setup` method during initialization.
The `client_setup` method is responsible for establishing interprocess communication with the server,
and selecting the correct ORM adapter for Updater.
It does this using the configuration file discussed later in this document.
This method can take an optional hash that will override the options in the configuration file.
It can also be passes a `:logger` option which will use the passed in logger instance for updater logging.

Scheduling Jobs
---------------

The core of Updater is placing Jobs on the queue to be run.
Jobs are scheduled using methods on the `Updater::Update` class.
Please see the rdoc entry for `Updater::Update#at` for more details
The following methods can be used to schedule jobs:
* `at(time, target, method, args, options)`: Schedules a job to run at a given time
* `in(delay, target, method, args, options)`: Schedules a job to run after a given interval
* `immidiate(target, method, args, options)`: Schedules a job to run immidiatly.
  
**target**: is the object (class or instance) that the method will be called on.

**method**: the method name as a string or symbol.
If this is unspesified `:preform` is asumed (a la Resque)

**args**: an array of objects that will be passed as arguments to the method.
Either leave this blank, or set to `[]` to call without arguments.
All members of the array must be marshalable.

**options**: a hash of extra information, details can be found in the Options section.

We intend to add a module that can be included into a target class
that will allow scheduling in the same general manner as delayed_job.
This addation is planned for version 1.2.

The Configuration File
----------------------

In updater both client and server use a single configuration file.
The location of this file can be set using the `UPDATE_CONFIG` environment variable.
When this is not set Updater will instead look for some intelligently chosen defaults.
These defaults are based on the assumption 
that the client is one of a number of popular web frameworks 
that use the rails directory structure.
It will look in either the current working directory or a subdirectory called `config`
(with preference for the latter) for a file called `updater.config`.
Failing that it will look for a .updater file in the current working directory.
Rake files should endeavor to set an appropriate working directory
before invoking the setup tasks.

The configuration itself is a ERb interpreted YAML file.
This is of use in limiting repetition, 
and in changing options based on the environment (test/development/production)

Please see the options section for details about the various options in this file.

Starting Workers (Server)
-------------------------

In the parlance of background job processing, 
a process that executes jobs is known as a worker.
The recommended way to start workers is through a rake task.
First, include `updater/tasks` in your application's Rakefile.
This will add start, stop and monitor tasks into the `updater` namespace.
`start` will use the options in your configuration file to start  a worker process.
Likewise, `stop` will shut that process down.
The monitor task will start an http server 
that you can use to monitor and control the job queue and workers.
(This feature is not currently implemented)

Individual workers are initialized and shutdown by a master process 
which monitors the work load and starts or stops individual workers as needed
within the limits established in the configuration file.
You should, therefore, only need to use `start` once.

