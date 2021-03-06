# Go vs Go

This is the source code for [govsgo.com](http://govsgo.com).

If you find a bug in the site or have a suggestion please post it on the [Issue Tracker](http://github.com/ryanb/govsgo/issues) or fork the project and submit a pull request.

## Setup

Ruby 1.9.2 is required. If you're using RVM it should automatically switch to 1.9.2 when entering the directory.

Run the following commands to set it up. Note the brew commands to install GNU Go and Beanstalk. You may want to use a different packaging system or install it from the source.

<pre>
bundle
cp config/database.example.yml config/database.yml
cp config/private.example.yml config/private.yml
rake db:create db:migrate
brew install gnu-go
brew install beanstalk
</pre>

After that you should be able to start it up with `rails s` and run the specs with `rake`.

To get the AI working you'll need to run `beanstalkd` and `script/play_computer_moves`.


## Credits

This site was originally created for Rails Rumble 2010 by Phil Bates, James Edward Gray II and Ryan Bates.
