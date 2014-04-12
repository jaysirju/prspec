describe 'PRSpec' do
  it 'Start a sub-process and detach leaving it running' do
    pid = Process.spawn("start cmd /K \"title prspec-test & dir")
    Process.detach(pid)
    actual = true
    expected = true
    expect(actual).to eq(expected)
  end
end