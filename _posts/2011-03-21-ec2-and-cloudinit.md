---
layout: post
title: "Initializing Amazon EC2 Instances with CloudInit"
categories:
- cloud
- cloudinit
- ec2
- linux
---
The last several blog posts have been about setting up and using Amazon EC2 instances.
One thing you may have noticed if you've been following along is that newly-launched
instances are pretty bare-bones; they have one user defined, and not much more software
installed than the absolute minimum. It's unlikely they're going to have the software
you need installed out of the box.

Sure, you can set everything up by hand, but that runs counter to one of the strong points of
running cloud instances -- being able to launch new instances rapidly, to scale up capacity
as fast as possible. There's also the problem of repeatability; the more complex the process,
the more steps involved in setting up a new instance, the more likely you are to leave out
a step.

The Linux images from both Amazon and Canonical include a package called
[CloudInit](http://help.ubuntu.com/community/CloudInit) which helps with both of these problems.

## Hey, you, get onto my cloud

CloudInit runs as a process at boot time. You pass data to it when launching the instance, via
either the `-d user_data` or `-f user_data_file` command-line options to `ec2-run-instances` [^fn1].
CloudInit interprets the data, handles it appropriately, then exits.

For the sake of repeatability, passing data directly on the command line seems like a bad idea.
(Not to mention the difficulty of passing a lot of data on the command line.) In these examples,
I'm going to stick to files and the `-f` option.

CloudInit can handle user data in a number of different formats. Let's look at some of them.

## User data scripts

The simplest and most straightforward format is the user data script. User data scripts are identified
by a first line starting with `#!` [^fn2]. The user data is written to a file on the newly-created
instance, which is then executed as root by the Unix program loader "very late in the boot sequence"
(according to the documentation). In essence, a user data script can look like nearly any normal
Unix script.

One thing you need to remember is that anything you try to execute in the script must
be available in the instance before you try to execute it. This usually means you either need to be
stingy with what you try to use, or install packages before using them.

As a simple example, here's a user data script named `user-script.txt` that will write to a file named
`user-script-output.txt` [^fn3] in the home directory of the `ec2-user` user.

{% highlight sh %}
  #!/bin/sh
  echo 'Woot!' > /home/ec2-user/user-script-output.txt
{% endhighlight %}

And here it is in action.

{% highlight sh %}
  $ ec2-run-instances --group default --key $EC2_KEYPAIR_NAME -f user-script.txt ami-d59d6bbc
  $ ec2-describe-instances
  RESERVATION   r-92c5b7ff      331055354537    default
  INSTANCE      i-badd25d5      ami-d59d6bbc    ec2-50-17-64-120.compute-1.amazonaws.com  \
                domU-12-31-39-15-64-0E.compute-1.internal   running ec2-keypair     0     \
                m1.small  2011-03-20T04:21:29+0000  us-east-1b  aki-407d9529              \
                monitoring-disabled     50.17.64.120        10.207.103.252                \
                instance-store          paravirtual xen
  $ ssh -i $EC2_KEYPAIR ec2-user@50.17.64.120
  
  [ec2-user@domU-12-31-39-15-64-0E ~]$ pwd
  /home/ec2-user
  [ec2-user@domU-12-31-39-15-64-0E ~]$ ls -l
  total 4
  -rw-r--r-- 1 root root 6 Mar 20 04:22 user-script-output.txt
  [ec2-user@domU-12-31-39-15-64-0E ~]$ cat user-script-output.txt 
  Woot!
{% endhighlight %}

## Include files

At The Day Job, we have several different configurations of servers, but each is based on different
combinations of the same packages. For instance, they all need Java; most but not all need Tomcat;
some need Subversion; and so on. Rather than maintain a number of monolithic user data scripts,
one for each configuration, it makes more sense to have a script for each component, then combine
them as needed.

To the best of my knowledge, you can't pass more than one instance of `-f` on the command line
when starting an instance. Fortunately, the next best thing is available: you can pass an
include file, which contains references to other user data files.

Include files are identified by a first line starting with `#include`. Subsequent lines contain
URLs which are read one at a time by CloudInit, loaded, and the data processed as user data. The
documentation is silent on whether the URLs are handled consecutively or concurrently, or whether
they're guaranteed to be handled in order. In other words, while you probably can assume that
later included user data can depend on previously included user data, you should test and confirm
for yourself that this is the case.

Note that the include file contains URLs rather than filenames. This is a mixed blessing; you
need to put the included files somewhere where the launching instance can load them (which is
likely not your workstation or laptop), but then they're in a central location, accessible to
all of your EC2 instances as needed. As an added benefit, if you store them on S3, the bandwidth
to read them isn't metered and doesn't incur additional charges.

For this example, we'll create three user data scripts, upload them to the Web [^fn4], then create an
include file which references all three. We'll do a simple test of whether the includes are
processed consecutively or concurrently as well.

The first script is named `script-1.sh`.

{% highlight sh %}
  #!/bin/sh
  HOME=/home/ec2-user
  sleep 20
  echo 'running' > $HOME/script-1-output.txt
  if [ -f $HOME/script-2-output.txt ]
    echo 'script-2 has run' >> $HOME/script-1-output.txt
  else
    echo 'script-2 has not run' >> $HOME/script-1-output.txt
  fi
  if [ -f $HOME/script-3-output.txt ]
    echo 'script-3 has run' >> $HOME/script-1-output.txt
  else
    echo 'script-3 has not run' >> $HOME/script-1-output.txt
  fi
{% endhighlight %}

The second script is named, naturally, `script-2.sh`.

{% highlight sh %}
  #!/bin/sh
  HOME=/home/ec2-user
  sleep 10
  echo 'running' > $HOME/script-2-output.txt
  if [ -f $HOME/script-1-output.txt ]
    echo 'script-1 has run' >> $HOME/script-2-output.txt
  else
    echo 'script-1 has not run' >> $HOME/script-2-output.txt
  fi
  if [ -f $HOME/script-3-output.txt ]
    echo 'script-3 has run' >> $HOME/script-2-output.txt
  else
    echo 'script-3 has not run' >> $HOME/script-2-output.txt
  fi
{% endhighlight %}

Working out what the third script is named is left as an exercise for the reader. :-)

{% highlight sh %}
  #!/bin/sh
  HOME=/home/ec2-user
  echo 'running' > $HOME/script-3-output.txt
  if [ -f $HOME/script-1-output.txt ]
    echo 'script-1 has run' >> $HOME/script-3-output.txt
  else
    echo 'script-1 has not run' >> $HOME/script-3-output.txt
  fi
  if [ -f $HOME/script-2-output.txt ]
    echo 'script-2 has run' >> $HOME/script-3-output.txt
  else
    echo 'script-2 has not run' >> $HOME/script-3-output.txt
  fi
{% endhighlight %}

Next, we need an include file which references all three of these user data scripts,
called `include.txt`.

{% highlight sh %}
  #include
  http://craigcottingham.github.com/code/cloud-init/script-1.sh
  http://craigcottingham.github.com/code/cloud-init/script-2.sh
  http://craigcottingham.github.com/code/cloud-init/script-3.sh
{% endhighlight %}

And here it is in action.

{% highlight sh %}
  $ ec2-run-instances --group default --key $EC2_KEYPAIR_NAME -f include.txt ami-d59d6bbc
  $ ec2-describe-instances
  RESERVATION   r-b40d76d9      331055354537    default
  INSTANCE      i-5cb97933      ami-d59d6bbc    ec2-184-73-11-176.compute-1.amazonaws.com \
                ip-10-114-46-188.compute-1.internal         running ec2-keypair     0     \
                m1.small  2011-03-22T03:39:13+0000  us-east-1b  aki-407d9529              \
                monitoring-disabled     184.73.11.176       10.114.46.188                 \
                instance-store          paravirtual xen
  $ ssh -i $EC2_KEYPAIR ec2-user@184.73.11.176
  
  [ec2-user@ip-10-114-46-188 ~]$ ls -l
  total 12
  -rw-r--r-- 1 root root 50 Mar 22 03:41 script-1-output.txt
  -rw-r--r-- 1 root root 46 Mar 22 03:41 script-2-output.txt
  -rw-r--r-- 1 root root 42 Mar 22 03:41 script-3-output.txt
  [ec2-user@ip-10-114-46-188 ~]$ cat script-1-output.txt 
  running
  script-2 has not run
  script-3 has not run
  [ec2-user@ip-10-114-46-188 ~]$ cat script-2-output.txt 
  running
  script-1 has run
  script-3 has not run
  [ec2-user@ip-10-114-46-188 ~]$ cat script-3-output.txt 
  running
  script-1 has run
  script-2 has run
{% endhighlight %}

So here we have empirical evidence that the included user data scripts are run consecutively
rather than concurrently.

## More advanced usage

There's a fairly advanced-looking data format called `cloud-config` which, unfortunately, is
not well documented beyond the "here's some examples" level. A good part of what _is_
documented seems to be specific to Ubuntu, so I'm not sure how useful it would be for the
Amazon AMIs.

If you need code to execute earlier than "late in the boot process", the `cloud-boothook` is
available. It appears to function similar to a user data script, with the additional
restriction that it should be idempotent [^fn5]. I was unable to find an example in the
documentation, so I don't know anything more about this data format.

Similarly, you can define upstart [^fn6] jobs directly with the `upstart-job` data format.

You can specify more than one data format in a single file by formatting it as a mime-multipart
message. I can see this as preferable to the include file only if all of the data is already
on your workstation or laptop, and you don't want to put it in a location accessible via URL.
For our purposes, this isn't an advantage.

Finally, if CloudInit determines that the user data is gzip compressed, it will decompress it
first before processing.

## Caveats

CloudInit can only process 16K of data, whether it's passed directly on the command line or in a
user data file. Gzip compression can help with that, but there's still a hard limit that you may
run in to. I'll talk about a possible solution in an upcoming post.


[^fn1]: Or perhaps both. I haven't seen examples of using both, and best as I can tell there's nothing
        in the documentation that says you can't use both in a single invocation. That's probably
        worth trying.

[^fn2]: The [shebang](http://en.wikipedia.org/wiki/Shebang_%28Unix%29).

[^fn3]: Okay, so I could be more creative in naming my files.

[^fn4]: I'm not using S3 for this example just because I like keeping the example files for this blog
        with the rest of the files for the blog.

[^fn5]: ["repeated applications have the same effect as one"](http://dictionary.reference.com/browse/idempotent).

[^fn6]: A replacement for `sysvinit`.
