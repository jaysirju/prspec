require 'prspec'

describe 'PRSpec' do
  it 'Start a sub-process and detach leaving it running' do
    actual = PRSpec.get_number_of_running_threads
    expected = 1
    expect(actual).to eq(expected)
  end
end