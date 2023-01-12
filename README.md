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

| Command flag    | Description                                                                                                                              |
|:----------------|:-----------------------------------------------------------------------------------------------------------------------------------------|
| `--silent`      | Silent log messages. Result will still be shown                                                                                          |
| `-b/--base`     | Specify base branch to analyze against. Default: origin/testflight                                                                       |
| `-u/--unstaged` | Analyze changes in unstaged files                                                                                                        |
| `-s/--staged`   | Analyze changes in staged files                                                                                                          |
| `-p/--path`     | Run in specified. Path must be git repo, i.e. path's directory has .git/                                                                 |
| `-f/--files`    | Analyze only specified file(s), space separated. Note: only files changed, committed or uncommitted, in current branch will be picked up |

**Examples**
```console
# no logs
ballercop fix --silent

# base branch
ballercop fix -b BBS-8220-epic
ballercop fix -b origin/BBS-8220 -u
ballercop fix -b origin/BBS-8220 -u -s

# different repo
ballercop fix -p ../workspace/baller
ballercop fix -p ../workspace/baller -f app/controllers/registrations_controller.rb

# specific files
ballercop fix -f app/controllers/registrations_controller.rb
ballercop fix -f app/controllers/registrations_controller.rb app/models/test_campaign.rb
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then create new PR.

To test against Baller repo locally, navigate to this (ballercop) repo's path locally, run `rake build` which will create a packaged build file under `pkg/`. Then, in baller repo, run `gem install [path]/pkg/[build_file]` where `path` is the relative path from 
baller repo to this repo on your local machine.

## Contributing

Pull down repo and contribute. Make sure to update CHANGELOG.md.