describe 'PRSpec' do
  it 'Sample 1 - Expect pass' do
    actual = 'Sample 1'
    expected = 'Sample 1'
    sleep(10)
    expect(actual).to eq(expected), "Result not as expected... expected: '#{expected}'; recieved: '#{actual}'"    
  end

  it 'Sample 2 - Expect pass' do
    actual = 'Sample 2'
    expected = 'Sample 2'
    sleep(10)
    expect(actual).to eq(expected), "Result not as expected... expected: '#{expected}'; recieved: '#{actual}'"    
  end
end