describe 'PRSpec' do
  it  '2 Spaces after it' do
    actual = true
    expected = true
    expect(actual).to eq(expected)
  end

  it '2 Spaces before do'  do
    actual = true
    expected = true
    expect(actual).to eq(expected)
  end

  it  'Tab after it' do
    actual = true
    expected = true
    expect(actual).to eq(expected)
  end

  it    '4 Spaces after it' do
    actual = true
    expected = true
    expect(actual).to eq(expected)
  end

  it'No Spaces after it' do
    actual = true
    expected = true
    expect(actual).to eq(expected)
  end

  it 'No Spaces before do'do
    actual = true
    expected = true
    expect(actual).to eq(expected)
  end

   it '3 Spaces before it' do
    actual = true
    expected = true
    expect(actual).to eq(expected)
  end

  it 'Tag before do', :tagged=>true  do
    actual = true
    expected = true
    expect(actual).to eq(expected)
  end
end