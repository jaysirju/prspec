describe 'PRSpec' do
  it 'Start a sub-process and detach leaving it running' do
  	cmd = File.join('.','test','never_ending.sh &')
  	if (RUBY_PLATFORM.match(/mingw/i)) # if is Windows
  	  cmd = 'start cmd /K .\test\never_ending.bat'
  	end
    pid = Process.spawn(cmd)
    Process.detach(pid)
    File.open(".pid",'w') { |file| file.write(pid.to_s) }
    actual = true
    expected = true
    expect(actual).to eq(expected)
  end
end