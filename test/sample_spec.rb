describe 'PRSpec' do
  it 'Sample 3 - Expect pass' do
    actual = 'Sample 3'
    expected = 'Sample 3'
    expect(actual).to eq(expected), "Result not as expected... expected: '#{expected}'; recieved: '#{actual}'"    
  end

  it 'Sample 4 - Expect fail' do
    actual = 'Sample 4'
    expected = 'Sample 1'
    expect(actual).to eq(expected), "Result not as expected... expected: '#{expected}'; recieved: '#{actual}'"    
  end

  it 'Sample 5 - Expect pass', :tagged=>true do
    actual = 'Sample 5'
    expected = 'Sample 5'
    expect(actual).to eq(expected), "Result not as expected... expected: '#{expected}'; recieved: '#{actual}'"    
  end

  it 'Sample 6 - Expect ignore' do
    pending    
  end
end