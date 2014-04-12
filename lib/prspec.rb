require 'thread'
require 'optparse'
require 'log4r'
require 'parallel'
require 'tempfile'
include Log4r

$log = Logger.new('prspec')
$log.outputters = Outputter.stdout
level = ENV['log_level'] || ''
case level.downcase
when 'all'
  $log.level = ALL
when 'debug'
  $log.level = DEBUG
when 'info'
  $log.level = INFO
when 'warn'
  $log.level = WARN
else
  $log.level = ERROR
end

class PRSpec
  attr_accessor :num_threads, :processes, :tests
  SPEC_FILE_FILTER = '_spec.rb'

  def initialize(args)
    if (!args.nil? && args.length > 0 && !args[0].nil?)
      opts = parse_args(args)
      if (!opts[:help])
        @num_threads = opts[:thread_count]

        @tests = get_spec_tests(opts)
        if (tests.length > 0)
          process_tests = divide_spec_tests(tests)
          $log.debug "#{tests.length} Spec tests divided among #{@num_threads} arrays."
        else
          $log.error "No spec tests found.  Exiting."
          exit 1
        end

        $log.info "Creating array of Child Processes..."
        @processes = build_process_array(process_tests, opts)
        
        begin_run(@processes, opts)
      end
    end
  end

  def parse_args(args)
    $log.debug("Parsing arguments of: #{args}")
    options = {
      :dir=>'.',
      :path=>'spec',
      :thread_count=>get_number_of_threads,
      :test_mode=>false,
      :help=>false,
      :excludes=>nil,
      :rspec_args=>[],
      :tag=>''
    }
    o = OptionParser.new do |opts|
      opts.banner = "Usage: prspec [options]"
      opts.on("-p", "--path PATH", "Relative path from the base directory to search for spec files") do |v|
        $log.debug "path specified... value: #{v}"
        options[:path] = v
      end
      opts.on("-e", "--exclude REGEX", "Regex string used to exclude files") do |v|
        $log.debug "excludes specified... value: #{v}"
        options[:excludes] = v
      end
      opts.on("-d", "--dir DIRECTORY", "The base directory to run from") do |v|
        $log.debug "directory specified... value: #{v}"
        options[:dir] = v
      end
      opts.on("-n", "--num-threads THREADS", "The number of threads to use") do |v|
        $log.debug "number of threads specified... value: #{v}"
        options[:thread_count] = v.to_i
      end
      opts.on("-t", "--tag TAG", "A rspec tag value to filter by") do |v|
        $log.debug "tag filter specified... value: #{v}"
        options[:tag] = v
      end
      opts.on("-r", "--rspec-args \"RSPEC_ARGS\"", "Additional arguments to be passed to rspec (must be surrounded with double quotes)") do |v|
        $log.debug "rspec arguments specified... value: #{v}"
        options[:rspec_args] = v.gsub(/"/,'').split(' ') # create an array of each argument
      end
      opts.on("--test-mode", "Do everything except actually starting the test threads") do
        $log.debug "test mode specified... threads will NOT be started."
        options[:test_mode] = true
      end
      opts.on("-q", "--quiet", "Quiet mode. Do not display parallel thread output") do
        $log.debug "quiet mode specified... thread output will not be displayed"
        options[:quiet_mode] = true
      end
      opts.on("-h", "--help", "Display a help message") do 
        $log.debug "help message requested..."
        options[:help] = true
        puts opts
      end
    end

    # handle invalid options
    begin 
      o.parse! args
    rescue OptionParser::InvalidOption => e
      $log.error e
      puts o
      exit 1
    end

    return options
  end

  def get_number_of_threads
    count = Parallel.processor_count
    return count
  end

  def self.get_number_of_running_threads
    cmd = "ps -ef"
    if (PRSpec.is_windows?)
      cmd = "wmic process get commandline"
    end
    result = `#{cmd}`
    count = 0
    lines = result.split("\n")
    lines.each do |line|
      if (line.include?('TEST_ENV_NUMBER='))
        count += 1
      end
    end
    $log.debug "Found #{count} occurrances of TEST_ENV_NUMBER"
    return count
  end

  def get_spec_tests(options)
    files = get_spec_files(options)
    tests = get_tests_from_files(files, options)
    $log.debug "Found #{tests.length} tests in #{files.length} files"
    return tests
  end

  def get_spec_files(options)
    base_dir = options[:dir]
    path = options[:path]
    if (path.nil? || path == '')
      path = '.'
    end
    full_path = ""
    if (path.end_with?('.rb'))
      full_path = File.join(base_dir, path.to_s)
    else
      full_path = File.join(base_dir, path.to_s, '**', "*#{SPEC_FILE_FILTER}")
    end
    $log.debug "full_path: #{full_path}"

    files = []
    if (options[:excludes].nil?)
      files = Dir.glob(full_path)
    else
      files = Dir.glob(full_path).reject { |f| f[options[:excludes]] }
    end

    return files
  end

  def get_tests_from_files(files, options)
    tests = []
    get_test_description = /(?<=')([\s\S]*)(?=')/
    match_test_name_format = /^[\s]*(it)[\s]*(')[\s\S]*(')[\s\S]*(do)/
    files.each do |file|
      rmatches = File.readlines(file).select { |line| line =~ match_test_name_format }
      rmatches.each do |m|
        tag = options[:tag]
        value = ''
        match = false
        if (options[:tag].include?(':')) # split to tag and value
          tag_value = options[:tag].split(':')
          tag = ":#{tag_value[0]}"
          value = "#{tag_value[1]}"
          if (m.index(tag) && (m.index(value) > m.index(tag))) # if tag not specified match using ''
            match = true
          end
        else
          if (m.index(tag))
            match = true
          end
        end
        if (match)
          tests.push('"'+m.match(get_test_description)[0].gsub(/["]/,"'")+'"')
        end
      end
    end

    return tests
  end

  def divide_spec_tests(tests)
    if (tests.length < @num_threads)
      @num_threads = tests.length
      $log.info "reducing number of threads due to low number of spec tests found: Threads = #{@num_threads}"
    end
    spec_arrays = Array.new(@num_threads)
    num_per_thread = tests.length.fdiv(@num_threads).ceil
    $log.debug "Approximate number of tests per thread: #{num_per_thread}"
    # ensure an even distribution
    i = 0
    tests.each do |tname|
      if (i >= @num_threads)
        i = 0
      end
      if (spec_arrays[i].nil?)
        spec_arrays[i] = []
      end
      
      spec_arrays[i].push(tname)

      i+=1
    end

    return spec_arrays
  end

  def build_process_array(process_tests, opts)
    processes = []
    for i in 0..@num_threads-1
      processes[i] = PRSpecThread.new(i, process_tests[i], {'TEST_ENV_NUMBER'=>i, 'HOME'=>nil}, opts)
    end
    return processes
  end

  def begin_run(processes, options)
    if (!processes.nil? && processes.length > 0)
      $log.info "Starting all Child Processes..."
      processes.each do |proc|
        if (proc.is_a?(PRSpecThread) && options.is_a?(Hash))
          proc.start unless options[:test_mode]
        else
          raise "Invalid datatype where PRSpecThread or Hash exepcted.  Found: #{proc.class.to_s}, #{options.class.to_s}"
        end
      end
      $log.info "Processes started..."
      continue = true
      while continue
        continue = false
        processes.each do |proc|
          if (!proc.done?) # confirm threads are running
            continue = true
            $log.debug "Thread#{proc.id}: alive..."
          else
            $log.debug "Thread#{proc.id}: done."
            puts proc.output unless options[:quiet_mode]
            proc.output = '' unless options[:quiet_mode] # prevent outputting same content multiple times
          end
        end
        if (continue)
          sleep(5) # wait a bit for processes to run and then re-check their status
        end
      end
      $log.info "Processes complete."
    else
      raise "Invalid input passed to method: 'processes' must be a valid Array of PRSpecThread objects"
    end
  end

  def running?
    @processes.each do |proc|
      if (!proc.done?)
        $log.debug "Found running process..."
        return true
      end
    end
    return false
  end

  def close
    @processes.each do |proc|
      proc.close
    end
  end

  def self.is_windows?
    return (RUBY_PLATFORM.match(/mingw/i)) ? true : false
  end
end

class PRSpecThread
  attr_accessor :thread, :id, :tests, :env, :args, :output
  def initialize(id, tests, environment, args)
    @id = id
    @tests = tests
    @env = environment
    @args = args
    @output = ''
    @out = "prspec-t-#{@id}.out"
    @err = "prspec-t-#{@id}.err"
  end

  def start
    filter_str = @tests.join(" -e ")
    filter_str = "-e " + filter_str
    exports = get_exports
    rspec_args = @args[:rspec_args].join(' ')
    cmd = "#{exports}rspec #{@args[:path]} #{filter_str} #{rspec_args}"
    $log.debug "Starting child process for thread#{@id}: #{cmd}"
    @thread = Thread.new do 
      Thread.current[:id] = @id
      Dir::chdir @args[:dir] do # change directory for process execution
        begin
          pid = Process.spawn(cmd, :out=>@out, :err=>@err) # capture both sdtout and stderr in the same pipe
          Process.wait(pid)
          @output = File.readlines(@out).join("\n")
        rescue
          error = "ErrorCode: #{$?.errorcode}; ErrorOutput: "+File.readlines(@err).join("\n")
          $log.error "Something bad happened while executing thread#{@id}: #{error}"
        end
      end
    end
  end

  def done?
    return !@thread.alive?
  rescue
    return true # if there's a problem with @thread we're done
  end

  def close
    if (!done?)
      @thread.stop
      @thread.kill
    end
    File.exist?(@out) ? File.delete(@out) : ''
    File.exist?(@err) ? File.delete(@err) : ''
  end

  def get_exports
    separator = PRSpec.is_windows? ? ' & ' : ';'
    exports = @env.map do |k,v|
      if PRSpec.is_windows?
        "(SET \"#{k}=#{v}\")"
      else
        "#{k}=#{v};export #{k}"
      end
    end.join(separator)

    return exports+separator
  end
end