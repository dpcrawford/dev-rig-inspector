function ConvertTo-MarkdownSingleLine {
    # Collapses embedded line breaks so a value can never introduce unintended Markdown blocks.
    param($Value)
    if ($null -eq $Value) { return '' }
    ([string] $Value) -replace "`r`n", ' ' -replace "`r", ' ' -replace "`n", ' '
}

function ConvertTo-MarkdownText {
    # Safe plain-text rendering: HTML-escapes angle brackets/ampersands and neutralizes table-breaking pipes.
    param($Value)
    $text = ConvertTo-MarkdownSingleLine -Value $Value
    $text = $text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
    $text -replace '\|', '\|'
}

function ConvertTo-MarkdownParagraph {
    # Same as ConvertTo-MarkdownText but also neutralizes a leading character that would start a heading/list/quote.
    param($Value)
    $text = ConvertTo-MarkdownText -Value $Value
    if ($text -match '^[#>*+-]' -or $text -match '^\d+\.') {
        $text = '\' + $text
    }
    $text
}

function ConvertTo-MarkdownCode {
    # Wraps a value as an inline code span with a backtick fence long enough to contain any embedded backticks.
    param($Value)
    if ($null -eq $Value -or ([string] $Value).Length -eq 0) { return [char] 0x2014 }
    $text = ConvertTo-MarkdownSingleLine -Value $Value
    $longestRun = 0
    foreach ($match in [regex]::Matches($text, '`+')) {
        if ($match.Length -gt $longestRun) { $longestRun = $match.Length }
    }
    $fence = '`' * ($longestRun + 1)
    if ($text.StartsWith('`') -or $text.EndsWith('`')) {
        '{0} {1} {2}' -f $fence, $text, $fence
    } else {
        '{0}{1}{2}' -f $fence, $text, $fence
    }
}

function ConvertTo-MarkdownTableCell {
    # Renders a table cell value and guarantees no literal pipe can break the row, even inside a code span.
    param($Value, [switch] $AsCode)
    $rendered = if ($AsCode) { ConvertTo-MarkdownCode -Value $Value } else { ConvertTo-MarkdownText -Value $Value }
    $rendered -replace '\|', '\|'
}
