# Ballercop
A safe rubocop auto fix for BallerTV

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ballercop', git: "git@github.com:ballertv/ballercop.git"
```

And then execute:

    $ bundle install


## Usage

### Fix

`$ ballercop fix`

By default, looks for staged ruby files (either added or changed), checks if 
there are any Rubocop offences with each file, and attempts to fix each offence.

> Note: Must run from baller root directory (where '.git/' exists)

#### Options

- Verbose [false]: Show messages from the cop. `ballercop fix --verbose`. "-v" shorthand
- Unstaged [false]: Check unstaged files too. `ballercop fix --unstaged`, "-u" shorthand

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then create new PR.

To test against Baller repo locally, run `rake build` which will create a packaged build file under `pkg/`. Then, in baller repo, run `gem install [path]/pkg/[build_file]` where `path` is the relative path from 
baller repo to this repo (ballercop) on your local machine.

## Contributing

Pull down repo and contribute.