# Run rspec tests in Parallel.

This gem will scan the specified directory for all spec files (those ending in '_spec.rb') and will collect a list of tests from within any matching files. These tests will then be evenly distributed among multiple parallel threads for execution using 'rspec'.

### Build Gem
```ruby
gem build prspec.gemspec
```

### Install
```ruby
gem install prspec-[version].gem
```

### Run
    prspec                      				# Run from current directory with default values (looks for tests in a 'spec' subdirectory)
    prspec -n 2                 				# Run from current directory using 2 threads (number will be reduced if number of tests is less than number of threads)
    prspec -d ../RspecTests     				# Run from '../RspecTests' directory
    prspec -p spec/ui_tests     				# Run from current directory executing only tests found in the 'spec/ui_tests' subdirectory and its child directories
    prspec -d ../RspecTests -p spec/ui_tests 	# Run from '../RspecTests' directory executing only tests found in the '../RspecTests/spec/ui_tests' subdirectory and its child directories
    prspec -t functional						# Run from current directory with default values any tests tagged with ':functional'
    prspec -t functional:always					# Run from current directory with default values any tests tagged with ':functional => "always"'
    prspec --test-mode 							# Test Mode: Run everything except for actually starting the parallel threads
    prspec -q 									# Quiet Mode: all output from the parallel threads will be hidden
    prspec -h 									# Display help message
    ...

### Known Issues
rspec tags must use the following format with the tag value surrounded with double quotes, not single quotes
```ruby
it 'some test', :tag_name => "tag_value" do
```

===================

Authors
====
inspired by [grosser/parallel_tests](https://github.com/grosser/parallel_tests)<br />
[Jason Holt Smith](https://github.com/bicarbon8)<br/>
bicarbon8@gmail.com<br/>
