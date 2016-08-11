---
layout: post
title: "Getting Started: A Behavior Driven Development Primer"
updated: 2011-03-06T18:39:00-06:00
categories:
- bdd
- cucumber
- rails
- rspec
- ruby
- testing
---
There are lots of perfectly useful tutorials on getting started with Rails, so I won't go into
a lot of detail there. I assume that you already have Ruby and Rails installed; as of the time of
this writing, I'm using versions 1.9.2 and 3.0.4 respectively.

## Set up Rails

Create a new Rails application:

{% highlight sh %}
  $ rails new bdd
  $ cd bdd
  $ git init .
  $ git commit -a -m 'Initial import'
{% endhighlight %}

Now run `rails server` and point your browser at http://localhost:3000/ to make sure that it runs.

Edit `Gemfile` and add these lines to the bottom:

{% highlight ruby %}
  group :development, :test do
    gem "rspec-rails", "~> 2.4"
    gem 'capybara'
    gem 'database_cleaner'
    gem 'cucumber-rails'
    gem 'cucumber', '>= 0.10.0'
    gem 'spork'
    gem 'launchy'
  end
{% endhighlight %}

Then run `bundle install` to update gems. Run `rails server` again as a sanity check.

## Set up RSpec

Install RSpec into the application:

{% highlight sh %}
  $ rails generate rspec:install
{% endhighlight %}

Configure the application to create specs instead of unit tests. Edit
`config/application.rb` and add to the bottom of the class definition:

{% highlight ruby %}
  config.generators do | g |
    g.test_framework :rspec
  end
{% endhighlight %}

## Set up Cucumber

Install Cucumber into the application:

{% highlight sh %}
  $ rails generate cucumber:install --rspec --capybara
{% endhighlight %}

## Test it out

First, generate the database:

{% highlight sh %}
  $ rake db:migrate
{% endhighlight %}

Make sure RSpec doesn't choke:

{% highlight sh %}
  $ rake spec
  No examples matching ./spec/**/*_spec.rb could be found
{% endhighlight %}

And that Cucumber doesn't, either:

{% highlight sh %}
  $ rake cucumber
  bundle exec ...
  Using the default profile...
  0 scenarios
  0 steps
  0m0.000s
{% endhighlight %}

Now we're ready to start writing features and specs.