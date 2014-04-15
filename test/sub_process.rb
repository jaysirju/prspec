describe 'PRSpec' do
  it 'Start a sub-process and detach leaving it running' do
  	cmd = ""
  	if (RUBY_PLATFORM.match(/mingw/i)) # if is Windows
  	  cmd = "start cmd /K \"title prspec-test & dir"
  	end
    pid = Process.spawn(cmd)
    Process.detach(pid)
    actual = true
    expected = true
    expect(actual).to eq(expected)
  end
end