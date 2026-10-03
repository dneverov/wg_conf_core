# WgConfCore

`WgConfCore` is a pure backend library designed to provide the core logic for the [wg_conf](https://github.com/dneverov/wg_conf) CLI toolset.

It handles managing, synchronizing, evaluating, and running WireGuard and AmneziaWG configuration files via Ruby. The library is completely isolated from terminal output (`puts`/`print`) and communicates exclusively using clean data structures and strict exceptions, making it perfectly suited for automation scripts, system services, or Telegram bots.

## Features

- **Configuration Management (`Config`)**: Handles secure system verification, path expansions, and lazy evaluation of configuration parameters.
- **Directory Synchronization (`FileCopier`, `Copier`)**: Manages safe bulk imports, file name tokenization, and dynamic conflict resolutions.
- **Status & Ping Checking (`VpnPinger`)**: Provides multi-threaded or sequential validation of live tunnel connections.
- **Interface Runner (`VpnRunner`)**: Safely controls `systemd` network interfaces, monitors active states, and catches low-level exceptions.

## Installation

Add this line to your application's `Gemfile`:

```ruby
gem 'wg_conf_core', git: 'https://github.com/dneverov/wg_conf_core', branch: 'master'
```

And then execute:

```bash
bundle install
```

## Running Tests

The core gem includes a robust unit testing environment. To execute the internal suite locally, run:

```bash
bundle exec rake test
```

## License

The gem is available as open source under the terms of the [MIT License](LICENSE).
