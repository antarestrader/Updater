Updater
=======

Updater is a background job queue processor.
It works a bit like 
[delayed_job](http://github.com/tobi/delayed_job) 
or [resque](http://github.com/defunkt/resque),
processing jobs in the background to allow user facing processes to stay responsive.
It also allow jobs to be scheduled and run at a particular time.
It is intended to work with a number of different ORM layers.
at the moment only DataMapper, and MongoDB are implemented.
Native support for ActiveRecord is planed.

Get it on GemCutter with `gem install updater`.

Main Features
-------------

* Handles both immediate and time delayed jobs
* Intelligent Automatic Scaling
* Does not poll the database
* Uses minimal resources when not under load
* Flexible Job Chaining allows for intelligent error handling and rescheduling (see Below)
* Powerful configuration with intelligent defaults
* Comes with `rake` tasks and binary.

These feature are as of ver 0.9.4.  See the change log for addational features

Use Cases
---------

Web based applications face two restrictions on their functionality
as it pertains to data processing tasks.
First, the application will only run code in response to a user request.
Updater handles the case of actions or events need to be triggered
without a request coming in to the web application.
Second, web applications, particularly those under heavy load,
need to handle as many request as possible in a given time frame.
Updater allows data processing and communication tasks
to happen outside of the request/response cycle
and makes it possible to move these tasks onto dedicated hardware

Updater is also useful for circumstances where code needs to be run
in a time dependent fashion,
particularly when these events need to be closely controlled by the code.

Updater is not a replacement for `cron`.
Jobs that are regular and repeating can be run
more consistently and with fewer resources with `cron`.
Updater should be considered when the application generates
a large number of one time events,
and/or the events need to be regularly manipulated by the application.

Updater is also not the optimal solution if the only goal
is to offload large numbers of immediate tasks.
For this the author recommends 
[resque](http://github.com/defunkt/resque)
by Chris Wanstrath.

Resque lacks a number of Updater's more powerful features,
and as of this writing we are not aware of any ability in resque
to set the time the job is run.
But resque does offer much higher potential throughput, and
a more robust queue structure backed by the Redis key-value store.

Using Updater
=============

Initial Installation
--------------------

Updater comes packaged as a gem and is published on GemCutter.
Get the latest version with `gem install updater`

The Updater source code is located at:
[http://github.com/antarestrader/Updater]([http://github.com/antarestrader/Updater])

Consepts
--------

Updater is not complex to use but it does, of necessity, have a number of *moving parts*.
In order to use updater successfully two tasks must be accomplished:
your application (referred to as the client) must be able to add jobs to the queue,
and a separate process (called the server, worker or job processor)
must be setup and run -- potentially on seperate hardware.
It will preform the actions specified in those jobs.

Jobs are stored in a data store that is shared between client and server.
Usually this data store will be a table in your database.
Other data stores are possible, but require significantly more configuration.
Updater is designed to have a minimal impact on the load of the data store,
and it therefore should be a reasonable solution for most applications. 
(For a discussion of when this is not a reasonable solution see 
[the Rescue Blog Post](http://github.com/blog/542-introducing-resque))

Updater is *very* flexible about what can be run in as a background job,
and this distinguishes it from other backgropund job processors.
The Job will call a single method on either a Class or an instance.
The method must be public.
Any arguments can be passed to the method so long as they can be marshaled.
It is important to keep in mind that the job will be run in a completely separate process.
Any global state will have to be recreated,
and data must be persisted in some form in order to be seen by the client.
For web applications this is usually not an issue.

Calling a class method is fairly strait forward,
but calling a method on an instance take a little more work.
Instances must be somehow persisted in the client
then reinstantiated on the worker process.
The assumption is that this will be done through the ORM and data store.
Each ORM adapter in Updater lists default methods 
for retrieving particular instances from the data store.
When an instance is scheduled as the target of a job,
its class and id will be stored in the `updates` table.
When the job is run,
it will first use the this class to pull the instance out of the data store,
then call the appropriate method on that instance.

(*Notes on nomenclature*: 
Jobs which run methods on a class are refered to throughout the documentationas "class type jobs",
while jobs which run methods on instances are called "instance type jobs."
The *target* of a job is the class or instance upon which the method is called.
A "conforming instance" is an instance of some class
which is persisted in the datastore 
and can be found by calling the default `finder_method` on its class
using the value returned by the default `finder_id` method.
ActiveRecord or DataMapper model instances are conforming instances
when updater is configured to use that ORM.
)

Client Setup
------------

The client application needs to do two things to be able to effectively schedule jobs:
1) require the `updater` library, and
2) call the `Updater::Setup.client_setup` method during initialization.
The `client_setup` method is responsible for establishing interprocess communication with the server,
and selecting the correct ORM adapter for Updater.
It does this using the configuration file discussed later in this document.
This method can take an optional hash that will override the options in the configuration file.
It can also be passes a `:logger` option.

With some ORM/datastore choices (only MongoDB at the moment)
it will also be necessary to pass the datastore connection to 
`Updater::ORM::<<OrmCklass>>.setup`.
See the Updater documentation for your ORM/datastore.

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

**options**: a hash of extra information, details can be found in the Options section of Updater::Update#at.

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

**Warning:** in its standard configuration, 
the config file will be read by the server to deturmine how to boot the app.
This has the unfortunate side effect the the framework's settings
will not be availible when this file is processed by ERb.

Please see the options section for details about the various options in this file.

Starting Workers (Server)
-------------------------

The recommended way to start workers is through a rake task.
First, include `updater/tasks` in your application's Rakefile.
This will add start, stop and monitor tasks into the `updater` namespace.
`start` will use the options in your configuration file to start a worker process.
Likewise, `stop` will shut that process down.
The monitor task will start an http server 
that you can use to monitor and control the job queue and workers.
(This feature is not currently implemented)

Individual workers are initialized and shutdown by a master process 
which monitors the work load and starts or stops individual workers as needed
within the limits established in the configuration file.
You should, therefore, only need to use `start` once.

Options:
--------

Options may be set in configuration file or passed in at runtime.

### General Configuration ###

*   `:orm`
    A string representing the ORM layer to use.
    the default is `datamapper` but this value should be set by all users of 
    versions < 1.0.0 as the default may change to `activerecord` once that ORM is implimented.
    Currently Updater supports `datamapper` and `mongodb`.
    Supprot for `activerecord` (>=3.0.0 only) will be implimented sometime after Rails 3 is released.
    Support for Redis is under investigation, patches welcome.
    
*   `:pid_file`
    This file will be created by the server and read by the client.
    Process signals are used as an alternate means of communication between client and server,
    and rake tasks make use of this file to start and stop the serve.
    The default is `ROOT\updater.pid` where ROOT is the location of the config file 
    or failing that the curent working directory. 
    
*   `:database`
    A hash of options passed to the Updater::ORM and used to establish a connection to the datastore,
    and for other ORM spesific setup.  See the Updater documentation for your chosen ORM.
    
*   `:config_file`
    Sets an alternate path the the config file.  Obviously useless in the actuall config file,
    this option can none the less be passed directly to client and server setup methods as 
    an extended option.  (See the cascade test.)  It can also be set by the command line binary
    using the `-c` option.
    
### Server Setup Options ###

*   `:timeout`
    Used only by the server,
    this is the length of time (in seconds) that the server will wait before killing a worker.
    It should be set to twice the length of the longes running job chain.
    
    Because the master worker process will kill off jobs that run too long,
    it is suggested that long jobs either be broken into smaller pieces using chains,
    placed in a special long running job queue,
    or forked off the worker process.

*   `:workers`
    This sets the maximum number of workers a single master server process may start.
    Each worker type has its own default, the recomended default `fork_worker` uses 3.
    The defaults are *very* conservitave, and so long as there are sufficient hardware
    resources, values fo 20 or more are not out of the question.
    
    The master worker process impliments a rather sophisticated heuristic
    that adjusts the number of workers actually spun up to match the current load.
    
    **Note:** It is likely that this option will be replaced by :max_workers before
    version 1.0, and that a :min_workers option will be added with a default of 1.
    Updater ignores unknown options so it is save to set :min_workers and :max_workers
    in antisipation of this change.
    
*   `:worker` (note singular)
    This option is a string which tells Updater which kind of worker to use.
    This option is only used by the server.
    Options are `fork` or `thread` with a `simple` planned 
    either before 1.0 or 1.2 depending on what the author needs.
    The default is 'fork' which is *strongly* recomended in production,
    but is not compatible with Microsoft Windows, and *may* be sub-optimal with JRuby.
    
    Windows user **must** set this option to `thread`.
    
*   `:models`
    This is actually an array of file names that the Server will require in order.
    Many users will simple put a single file that loads their whole framework here.
    (eg. `config/environment.rb` for Rails)
    
    These files must allow the server to setup an Ruby environment in which all possible
    job targets can be found, and the methods on those targets can be run.
    An application that makes only minimal use of Updater,
    and whose target classes and methods are carefully written,
    might be able to only require a subset of the full application,
    thus saving on system resources and improving start times.

### Logging ###

*   `:logger`
    An instance of a Ruby Logger or another object that uses the same interface.
    See Also :log_file and :log_level, which this command supercedes
    
*   `:log_file`
    The file to which Updater will log its actions.
    Most logging is done by the server.
    If no file is given SDTOUT is assumed
    Note that if the `:logger` option is set, this option is ignored.
    
*   `:log_level`
    One of the standare logging levels (failure error warn info debug).
    Updater will accept either symbols or strings and will automatically upcase this value.
    The defauld value is `warn`.
    Note that if the `:logger` option is set, this option is ignored.
    
    It should be noted that the server produces a prodigious amount of data at the debug level.
    (several MB/per day without any jobs; several MB per minute under load)
    We therefore strongly recomend that the server log level not be set below info without cause.
    The client on the other hand is quite safe even at the debug level in development and staging environments.
    
### IPC ###

Any or all or none of these options may be given.
If the option is not given the communications channel will not be used.
The server will listen on all channels given,
while clients will communicate on the "best" only.
Options are listed from "best" to "worst."
If the client cannot use any of these options,
it will use process signals as a last resort.

These methods of communicaion mearly signal to a worker process that a job
has been placed in the data store.  The client and server still must have access
to the same datastore.

*   `:socket`
    The path to a UNIX socket.
    The server will create and listen on this socket, clients can connect to it.
    This option is only viable for a server running on the same machine as the client,
    and will not work on Windows.
    
*   `:udp`
    The port number for UDP communications.
    This is the prefered option for a cluster configuration.
    
    **Security Notice:** Updater makes no effort to verify the authentisity of
    network connections.  Administrators should configure network topology and firewalls
    to ensure that only intended clients can communicate with the Updater server.
    
*   `:tcp`
    The port number for TCP comminications.
    This is the prefered option for VPN connections between remote locations.
    
     **Security Notice:** Updater makes no effort to verify the authentisity of
    network connections.  Administrators should configure network topology and firewalls
    to ensure that only intended clients can communicate with the Updater server.
    
*   `:host`
    The host name for UDP and TCP connections.
    The devault is 'localhost'.
    See security warnings above.
    
*   `:remote` (client only) (**Pending**)
    This is the url of a server monitor.
    This is the prefered option for remote operations over an unsecurted network.
    
    On an unsecured network, authentication becomes necessary.
    The server core is not equipt for authentication.
    Instead, a monitor server is started.
    This monitor has a secured connection to the worker master process using one of the methods above.
    The monitor recieves HTTP POST requests from authenticated clients,
    and translates them into job-ready notifications.
    
*   `:sockets` (note plural)
    Generally for internal use.
    This is an array of established Socket connections 
    that are passed directly to the worker master process.
    The server will listen for new connections on these sockets.
    This cannot be set in the configuration file,
    it may only be passed as an option to Updater::Setup#start.


Chained Jobs:
=============

One of the most exciting features of Updater is Job Chaining.
Each job has three queues
(`:success`, `:ensure` and `:failure`)
that point to other jobs in the queue.
These jobs are run after the initial job completes
depending on whether the job finished withour raising an error.
Jobs can in this way form a tree 
(processed depth first)
of related tasks.
This allows for code reuse,
and extreeme flexibility when it comes to takes such as
error handling, logging, auditing, and the like.

Update will eventually come with a standard library of chained jobs
which will be found in the Updater::Chains class.
(TODO: Chains are being written for the 0.9 version in responce to developer needs.
watch point releases for new chained methods)

Adding Chained Jobs
-------------------

Jobs can be created with chained jobs by passing
`:success`, `:ensure` and/or `:failure`
as options to any of the job queuing methods.
The value of these keys can be job, and array of jobs,
or a hash where keys are jobs and values are options passes into the `__params__` argument (see below)

(*Notes on nomenclature*:
An initial job is one that was scheduled and run in the regular fassion 
and not as a result of any chain.
A chained job is a job that is run by another job in responce to a chain.
)

Example:
    
    # Assume self is a conforming instance
    # Create a job to chain into
    logging_job = Updater::Update.chained(MyLoggingClass,:log_errors,[:__job__,:__params__])
    # Create a job that will call this job in the case of an error
    Updater::Update.immidiate(
        self,
        :some_method_that_might_fail,
        [val1,val2],
        :failure=>{logging_job=>{:message=>"an Epic Fail"}}
      )
    
    # [...]
    
    class MyLoggingClass
      def self.log_errors(job,options)
        logger.error "There was {options[:message] || "failure"} while processing a job:  \n %s" % job.error.mesage
        logger.debug job.error.backtrace.join('\n')
      end
    end
    
Here, the worker will recreate `self` by pulling its information from the datastore.
The worker will then send `:some_method_that_might_fail` to that instance with `val1` and `val2`.
If `:some_method_that_might_fail` raises an error,
the worker will then run `logging_job`.
This job will send :log_errors to the `MyLoggingClass` class replacing `:__job__` with the instance of the job that failed,
and `:__params__` replaced with `{:message=>"Epic Fail"}`.
`MyLoggingClass` can use the first argument to get the error that `:some_method_that_might_fail` raised.

Chained methods can also be added after a job is created by inserting them into the appropriate array.
Notice however that an immidiate job may have already run before you have the chance to add a chained job.

Example:

    #Simular to above
     Create a job to chain into
    logging_job = Updater::Update.chained(MyLoggingClass,:log_errors,[:__job__,:__params__])
    # Create a job that will call this job in the case of an error
    initial_job = Updater::Update.in(
        5.minutes,
        self,
        :some_method_that_might_fail,
        [val1,val2])
    initial_job.failure << logging_job
    
Writing Chained Jobs
--------------------

It is intended that chained jobs be reused.
The examples above created a new job to be chained for each initial job.
This is inefficient and would fill the datastore with unnecessary repeatition.
Instead, chained jobs should be placed into the datestore on first use,
then refered to by each new initial job.

To facilitate this Updater impliments three special fields in the arguments list
which are replaced with metadata before a job is called:

* `__job__`: replaced with the instance of Updater::Update that chained into
  this job.  If the job failed (that is raised and error while being run), this
  instance will contain an error field with that error.
* `__params__`: this is an optional field of a chain instance.  It allows the 
  chaining job to set specific options for the chained job to use. For example
  a chained job that reschedules the the original job might take an option 
  defining how frequently the job is rescheduled.  This would be passed in 
  the params field.  (See example in Updater::Chained -- Pending!)
* `__self__`:  this is simply set to the instance of Updater::Update that is 
  calling the method.  This might be useful for both chained and original
  jobs that find a need to manipulate of inspect that job that called them.
  Without this field, it would be impossible for a method to consistantly 
  determin wether it had been run from a background job or invoked
  direclty by the app.
 
Chained jobs can take advantage of these parameters to respond appropriatly without
having to have a new chiain job for each initial job.

Example: We could replace the `logging_job` above like this

    class MyLoggingClass
      def self.logging_job
        # We will memoize this value so we don't have to hit the datastore each time.
        # If the job is alread in the datastore, we will find it and use it,
        # Otherwise, we will create it from scratch.
        @logging_job ||= Updater::Update.for(self,'logging') || Updater::Update.chained(self,:log_errors,[:__job__,:__params__], :name=>'logging')
      end
      
      def self.log_errors
        # [...] As above
      end
    end
    
    # [...]
    
    #Updater::Update.immidiate(
        self,
        :some_method_that_might_fail,
        [val1,val2],
        :failure=>{MyLoggingClass.logging_job=>{:message=>"an Epic Fail"}}
      )

See Also: Once it is started, see the example in Updater::Chains -- pending