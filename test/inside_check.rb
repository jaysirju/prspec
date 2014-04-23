require 'prspec'

describe 'PRSpec' do
  it 'Check number of running threads from inner test' do
    sleep 5
    actual = PRSpec.get_number_of_running_threads
    expected = 3
    expect(actual).to eq(expected)
  end

  it 'Check number of running threads from inner test after one completes' do
    sleep 10
    actual = PRSpec.get_number_of_running_threads
    expected = 2
    expect(actual).to eq(expected)
  end

  it 'Check number of running threads from inner test after two complete' do
    sleep 15
    actual = PRSpec.get_number_of_running_threads
    expected = 1
    expect(actual).to eq(expected)
  end
end