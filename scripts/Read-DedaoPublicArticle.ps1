param(
    [Parameter(Mandatory = $true)][string]$Url,
    [int]$Start = 0,
    [int]$Length = 12000
)

# Read the same public endpoints referenced by Dedao's published web scripts.
# No browser cookies, account credentials, media downloads, or access overrides.
$ErrorActionPreference = 'Stop'
$articleUri = [uri]$Url
if ($articleUri.Host -ne 'www.dedao.cn' -or $articleUri.AbsolutePath -ne '/course/article') {
    throw 'Expected a www.dedao.cn/course/article URL.'
}
$idMatch = [regex]::Match($articleUri.Query, '(?:^\?|&)id=([A-Za-z0-9]+)(?:&|$)')
if (-not $idMatch.Success) { throw 'Article id missing.' }
if ($Start -lt 0 -or $Length -lt 1) { throw 'Invalid text range.' }
$requestBody = @{ detail_id = $idMatch.Groups[1].Value } | ConvertTo-Json -Compress
$info = Invoke-RestMethod -Uri 'https://www.dedao.cn/pc/bauhinia/pc/article/info' -Method Post -ContentType 'application/json' -Body $requestBody -TimeoutSec 30
if ($null -eq $info.h -or $info.h.c -ne 0) { throw ('Article metadata denied: ' + $info.h.e) }
if ($info.c.ptype -ne 24 -or [string]::IsNullOrWhiteSpace($info.c.dd_article_token)) {
    throw 'This reader only supports anonymous free-column articles with server-issued reading access.'
}
$publicArticleToken = [uri]::EscapeDataString($info.c.dd_article_token)
$bodyUrl = 'https://www.dedao.cn/pc/ddarticle/v1/article/get/v2?token=' + $publicArticleToken + '&sign=b23a426b357d1b83&appid=1632426125495894021&is_new=1'
$article = Invoke-RestMethod -Uri $bodyUrl -TimeoutSec 30
if ($null -eq $article.h -or $article.h.c -ne 0) { throw ('Article body denied: ' + $article.h.e) }
$blocks = $article.c.content | ConvertFrom-Json
$paragraphs = foreach ($block in $blocks) {
    if ($block.text) { [string]$block.text }
}
$plainText = $paragraphs -join "`n`n"
Write-Output ('Title: ' + $info.c.article_title)
Write-Output ('Source: ' + $Url)
Write-Output ('Characters: ' + $plainText.Length)
Write-Output ('Range start: ' + $Start)
if ($Start -lt $plainText.Length) {
    Write-Output $plainText.Substring($Start, [Math]::Min($Length, $plainText.Length - $Start))
}
