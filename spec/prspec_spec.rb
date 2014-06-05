require_relative '../lib/prspec.rb'
require 'rspec'
require 'parallel'
require 'timeout'
require 'fileutils'
require 'date'

RSpec.configure do |config|
  config.around(:each) do |example|
    # ensure tests are killed after 30 seconds if they don't complete
    # this is used to verify prspec honours detaching from subprocesses correctly
    Timeout::timeout(60) {
      example.run
    }
  end

  config.before(:suite) do
    $p = PRSpec.new(['--test-mode']) # test mode
  end

  config.before(:each) do
    $stdout = StringIO.new # capture STDOUT
    $stderr = StringIO.new # capture STDERR
  end

  config.after(:each) do
    $stdout = STDOUT
    $stderr = STDERR
  end

  config.after(:suite) do
    begin
      pid = File.read('.pid')
      kill_pid(pid)

      FileUtils.remove_file('.pid', :force => true) if File.exists?('.pid')
      path = "*.{out,err}"
      delete_files = Dir.glob(path)
      delete_files.each do |file|
        File.unlink file
      end
    rescue
      # do nothing
    end
  end
end

describe 'PRSpec Tests' do
  it 'Get help message' do
    expected = 'Usage: prspec [options]
    -p, --path PATH                  Relative path from the base directory to search for spec files
    -e, --exclude REGEX              Regex string used to exclude files
    -d, --dir DIRECTORY              The base directory to run from
    -n, --num-threads THREADS        The number of threads to use
    -t, --tag TAG                    A rspec tag value to filter by
    -r, --rspec-args "RSPEC_ARGS"    Additional arguments to be passed to rspec (must be surrounded with double quotes)
        --test-mode                  Do everything except actually starting the test threads
    -q, --quiet                      Quiet mode. Do not display parallel thread output
    -h, --help                       Display a help message
        --ignore-pending             Ignore all pending tests
    -s, --serialize-output           Wait for each thread to complete and then output to STDOUT serially
'
    path = File.join('.', 'lib','prspec.rb')
    actual = `ruby -r "#{path}" -e "PRSpec.new(['-h'])"`
    expect(actual).to end_with(expected), "Help message did not end with expected string... expected: '#{expected}'; recieved: '#{actual}'"    
  end

  it 'Verify invalid parameter results in program exit and help message displayed' do
    expected = 'Usage: prspec [options]
    -p, --path PATH                  Relative path from the base directory to search for spec files
    -e, --exclude REGEX              Regex string used to exclude files
    -d, --dir DIRECTORY              The base directory to run from
    -n, --num-threads THREADS        The number of threads to use
    -t, --tag TAG                    A rspec tag value to filter by
    -r, --rspec-args "RSPEC_ARGS"    Additional arguments to be passed to rspec (must be surrounded with double quotes)
        --test-mode                  Do everything except actually starting the test threads
    -q, --quiet                      Quiet mode. Do not display parallel thread output
    -h, --help                       Display a help message
        --ignore-pending             Ignore all pending tests
    -s, --serialize-output           Wait for each thread to complete and then output to STDOUT serially
'
    path = File.join('.', 'lib','prspec.rb')
    actual = `ruby -r "#{path}" -e "PRSpec.new(['-z','foo'])"`
    expect(actual).to end_with(expected), "Help message did not end with expected string... expected: '#{expected}'; recieved: '#{actual}'"    
  end

  it 'Verify default number of available Processes' do
    expected = Parallel.processor_count
    actual = $p.get_number_of_processors
    expect(actual).to eq(expected), "Expected the default number of threads, #{actual}, to match the number of processors available on the machine: #{expected}"
  end

  it 'Verify ability to specify small number of Processes' do
    expected = 1
    p = PRSpec.new(['-n', '1', '--test-mode'])
    actual = p.num_threads
    expect(actual).to eq(expected), "Expected the number of threads, #{actual}, to match the number specified in passed in arguments even though there are many tests: #{expected}"
  end

  it 'Verify number of Processes automatically reduced if low number of tests' do
    expected = 2
    p = PRSpec.new(['-p','test/sample.rb','-n','5','--test-mode'])
    actual = p.num_threads
    expect(actual).to eq(expected), "Expected the number of threads, #{actual}, to match the number of tests available in the spec file: #{expected}"
  end

  it 'Verify number of running threads when tests running' do
    p = PRSpec.new(['-p','test/inside_check.rb','-n','5','-q']) # this will run test/inside_check.rb which verifies that running process count is correct
    actual = p.output
    expect(actual).not_to eq(''), "Expected that a test would run and have some output, but did not"
    expect(actual).to include("3 examples, 0 failures"), "Expected that the test found a running process and passed, but did not: #{actual}"
  end

  it 'Verify process completes when subprocess is spawned and detached' do
    if is_windows? # currently doesn't run in Travis CI
      p = PRSpec.new(['-p','test/sub_process.rb','-q']) # this will run test/sub_process.rb
      sleep(15) # allow time for the tests to complete
      expect(p.running?).to eq(false), "Expected to pass if process detaches correctly, but did not"
      pid = File.read('.pid')
      count = 0
      FileUtils.remove_file('never_ending.out', :force => true)
      sleep 4
      if (File.exists?('never_ending.out'))
        count = 1
      end
      while File.exists?('never_ending.out')
        pid = File.read('never_ending.out')
        kill_pid(pid)
        FileUtils.remove_file('never_ending.out', :force => true)
        sleep 2
      end
      sub_process_found = (count >= 1)
      expect(sub_process_found).to eq(true), "Expected that the subprocess is still running, but was not.  Found #{count}"
    end
  end

  it 'Verify begin_run handles nil input' do
    expect { $p.begin_run(nil, {:test_mode => true}) }.to raise_error("Invalid input passed to method: 'processes' must be a valid Array of PRSpecThread objects")
  end

  it 'Verify begin_run handles wrong datatype input' do
    expect { $p.begin_run(['foo'], {:test_mode=>true}) }.to raise_error
    expect { $p.begin_run([PRSpecThread.new(nil,nil,nil,nil)], 'foo') }.to raise_error
  end

  it 'Verify handling of -p with filename specified' do
    expect { PRSpec.new(['-p','prspec.rb','-d','./lib']) }.to raise_error, "Expected to be able to specify a filename containing no tests in the path and for the program to halt, but did not"
    p = PRSpec.new(['-p','test/sample.rb', '--test-mode'])
    expect(p.tests.length).to eq(2), "Expected to be able to specify a filename in the path and still find tests, but did not"
  end

  it 'Verify handling of -p using default filename search pattern' do
    p = PRSpec.new(['-p','test', '--test-mode'])
    expect(p.tests.length).to eq(8), "Expected searches restricted to filenames ending with _spec.rb only, but was not"
  end

  it 'Verify handling of bad spacing in spec files' do
    p = PRSpec.new(['-p','test/error_sample.rb','--test-mode'])
    expect(p.tests.length).to eq(10), "Expected bad spacing to be handled correctly, but was not.  Found: #{p.tests.length}"
    expect(p.tests.include?('"2 Spaces before do"')).to be_true, "Expected that the non-inline example is identified correctly, but was not: #{p.tests}"
    expect(p.tests.include?('"Single line example"')).to be_true, "Expected that the inline example is identified correctly, but was not: #{p.tests}"
    expect(p.tests.include?('"Single line example with tag"')).to be_true, "Expected that the inline example with tag is identified correctly, but was not: #{p.tests}"
  end

  it 'Verify creation of Processes' do
    expected = $p.get_number_of_processors
    if (expected <= 21)
      actual = $p.num_threads
      expect(actual).to eq(expected), "Expected the number of Threads created, #{actual}, to equal the number of processors available on the machine: #{expected}"
    else
      # very high number of processors so ignore test
    end
  end

  it 'Verify is_windows?' do
    expected = (RUBY_PLATFORM.match(/mingw/i)) ? true : false
    actual = PRSpec.is_windows?
    expect(actual).to eq(expected), "Expected platform detection to return #{expected.to_s}, but returned #{actual.to_s}"
  end

  it 'Verify -r arguments get passed to rspec calls' do
    p = PRSpec.new(['-p','test', '-r', '"--format documentation --out tagged.out"']) # expect to run only 1 test
    expect(File.exists?('tagged.out')).to eq(true), "Expected that the rspec --out argument would create a file of name 'tagged.out', but did not"
    File.delete('tagged.out')
  end

  it 'Verify -t filters by expected tags' do
    p = PRSpec.new([
      '-p','test',    # look in 'test' directory
      '-t', 'tagged', # run tests tagged with :tagged => true
      '-q',           # use quiet mode
      '-n', '1'])     # run in a single thread
    actual = p.output
    expect(actual).not_to eq(''), "Expected that a test would run and have some output, but did not"
    expect(actual).to include("Sample\\ 5\\ \\-\\ Expect\\ pass"), "Expected that the tagged test would be run, but it wasn't: #{actual}"
    expect(actual).not_to include("Sample\\ 4\\ \\-\\ Expect\\ pass"), "Expected that the un-tagged tests would not be run, but they were: #{actual}"
  end

  it 'Verify -t filters by expected tags singlequote' do
    p = PRSpec.new([
      '-p','test',    # look in 'test' directory
      '-t', 'tagname:tagvalue', # run tests tagged with :tagname => 'tagvalue'
      '-q',           # use quiet mode
      '-n', '1'])     # run in a single thread
    actual = p.output
    expect(actual).not_to eq(''), "Expected that a test would run and have some output, but did not"
    expect(actual).to include("Tag\\ Value\\ surrounded\\ by\\ singlequotes"), "Expected that the tagged test would be run, but it wasn't: #{actual}"
    expect(actual).not_to include("Sample\\ 4\\ \\-\\ Expect\\ pass"), "Expected that the un-tagged tests would not be run, but they were: #{actual}"
  end

  it 'Verify -t filters by expected tags doublequote' do
    p = PRSpec.new([
      '-p','test',    # look in 'test' directory
      '-t', 'double:double', # run tests tagged with :double => "double"
      '-q',           # use quiet mode
      '-n', '1'])     # run in a single thread
    actual = p.output
    expect(actual).not_to eq(''), "Expected that a test would run and have some output, but did not"
    expect(actual).to include("Tag\\ Value\\ surrounded\\ by\\ doublequotes"), "Expected that the tagged test would be run, but it wasn't: #{actual}"
    expect(actual).not_to include("Sample\\ 4\\ \\-\\ Expect\\ pass"), "Expected that the un-tagged tests would not be run, but they were: #{actual}"
  end

  it 'Verify handling of --ignore-pending' do
    p = PRSpec.new(['-p','test', '--test-mode', '--ignore-pending'])
    expect(p.tests.length).to eq(7), "Expected only non-pending tests to be returned, but was not: #{p.tests.length} found"
  end

  it 'Verify descriptions containing double and single quotes are run successfully' do
    p = PRSpec.new(['-p','test', '-q', '-n', '1']) # expect to run all in a single thread
    actual = $stdout.string
    expect(actual).to eq(''), "Expected that the output would not be sent to STDOUT, but it was: #{actual}"
    actual = p.output
    expect(actual).not_to eq(''), "Expected that a test would run and have some output, but did not"
    expect(actual).to include("Sample\\ 5\\ \\-\\ Expect\\ pass"), "Expected that a normal test would be run, but it wasn't: #{actual}"
    expect(actual).to include("8 examples, 1 failure, 1 pending"), "Expected to run all tests, but didn't: #{actual}"
  end

  it 'Verify serialized output' do
    p = PRSpec.new(['-p','test/sample.rb', '-s', '-n', '2']) # expect to run all in a single thread
    actual = p.output
    expect(actual).to eq(''), "Expected that the output would not be collected, but it was: #{actual}"
    actual = $stdout.string
    expect(actual).not_to eq(''), "Expected that the output would be sent serially to STDOUT, but was not"
    expect(actual).to include("Sample\\ 1\\ \\-\\ Expect\\ pass"), "Expected that a normal test would be run, but it wasn't: #{actual}"
    expect(actual).to include("Sample\\ 2\\ \\-\\ Expect\\ pass"), "Expected that a normal test would be run, but it wasn't: #{actual}"
    expect(actual).to include("1 example, 0 failures"), "Expected to run all tests, but didn't: #{actual}"
    expect(actual).not_to include("1 example, 1 failure"), "Expected all tests to pass, but didn't: #{actual}"
  end
end

def is_windows?
  return (RUBY_PLATFORM.match(/mingw/i)) ? true : false
end

def kill_pid(pid)
  begin
    if (is_windows?) # if is Windows
      `taskkill /F /PID #{pid}`
    else
      `kill #{pid}`
    end
  rescue
    # do nothing
  end
end