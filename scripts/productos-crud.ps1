param(
  [string]$Command = "help",
  [string]$Name,
  [double]$Price = 0,
  [string]$Id
)

$BaseUrl = "http://productosapi-alb-1646067421.us-east-1.elb.amazonaws.com/api/v1/products"

function Show-Usage {
  @'
Uso: .\scripts\productos-crud.ps1 <comando> [args]

Comandos:
  list                     GET todos los productos
  get <id>                 GET producto por UUID
  create <name> <price>    POST nuevo producto (abre bloc de notas)
  update <id>              PUT actualizar producto (abre bloc de notas)
  delete <id>              DELETE producto
'@
}

function Write-Response($r) {
  if ($r.Content) {
    $r.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
  } else {
    Write-Host $r.StatusCode $(if ($r.StatusDescription) { "- $($r.StatusDescription)" })
  }
}

function Write-ErrorBody($ex) {
  try {
    # 1. Intentar capturar la respuesta HTTP cruda a través de la excepción de red
    if ($ex.Exception.Response) {
      $stream = $ex.Exception.Response.GetResponseStream()
      $reader = [System.IO.StreamReader]::new($stream)
      $body = $reader.ReadToEnd()
      $reader.Close()
      $stream.Close()
      
      if ($body) {
        # Intenta formatearlo como JSON, si no, lo muestra como texto crudo
        try {
          $body | ConvertFrom-Json | ConvertTo-Json -Depth 10
        } catch {
          Write-Host "Respuesta cruda del servidor: $body" -ForegroundColor Yellow
        }
        return
      }
    }
    
    # 2. Si no hay stream de respuesta pero hay detalles en el registro de error de PowerShell
    if ($ex.ErrorRecord.ErrorDetails.Message) {
      Write-Host "Detalles: $($ex.ErrorRecord.ErrorDetails.Message)" -ForegroundColor Yellow
    } else {
      Write-Host "Error general: $($ex.Message)" -ForegroundColor Red
    }
  } catch {
    # 3. Caso de emergencia extrema: Mostrar lo que sea que tenga la excepción
    Write-Host "Excepción capturada: $($ex.Message)" -ForegroundColor Red
    if ($ex.Exception) { Write-Host "Causa: $($ex.Exception.Message)" -ForegroundColor DarkRed }
  }
}

function Invoke-List {
  Write-Host "--- GET $BaseUrl ---" -ForegroundColor Cyan
  try {
    $r = Invoke-WebRequest -Uri $BaseUrl -Method Get
    Write-Response $r
  } catch {
    Write-ErrorBody $_
  }
}

function Invoke-Get {
  if (-not $Id) { Write-Error "Falta parámetro -Id"; return }
  $url = "$BaseUrl/$Id"
  Write-Host "--- GET $url ---" -ForegroundColor Cyan
  try {
    $r = Invoke-WebRequest -Uri $url -Method Get
    Write-Response $r
  } catch {
    Write-ErrorBody $_
  }
}

function Invoke-Create {
  $tmp = "$env:TEMP\producto_$(Get-Random).json"
  $uuid = [guid]::NewGuid().ToString()
  @"
{
  "id": "$uuid",
  "name": "$Name",
  "price": $Price
}
"@ | Out-File -FilePath $tmp -Encoding utf8

  notepad $tmp
  Write-Host "Presiona ENTER cuando termines de editar el JSON..." -ForegroundColor Yellow
  $null = Read-Host

  $body = Get-Content $tmp -Raw
  Write-Host "--- POST $BaseUrl ---" -ForegroundColor Cyan
  try {
    $r = Invoke-WebRequest -Uri $BaseUrl -Method Post -ContentType "application/json" -Body $body
    Write-Response $r
  } catch {
    Write-ErrorBody $_
  }
  Remove-Item $tmp -Force
}

function Invoke-Update {
  if (-not $Id) { Write-Error "Falta id"; return }
  $url = "$BaseUrl/$Id"
  Write-Host "Descargando producto actual..." -ForegroundColor Cyan
  try {
    $current = Invoke-RestMethod -Uri $url -Method Get
    $tmp = "$env:TEMP\producto_$(Get-Random).json"
    $current | ConvertTo-Json -Depth 10 | Out-File -FilePath $tmp -Encoding utf8
    notepad $tmp
    Write-Host "Presiona ENTER cuando termines de editar el JSON..." -ForegroundColor Yellow
    $null = Read-Host
    $body = Get-Content $tmp -Raw
    Write-Host "--- PUT $url ---" -ForegroundColor Cyan
    $r = Invoke-WebRequest -Uri $url -Method Put -ContentType "application/json" -Body $body
    Write-Response $r
    Remove-Item $tmp -Force
  } catch {
    Write-ErrorBody $_
  }
}

function Invoke-Delete {
  if (-not $Id) { Write-Error "Falta id"; return }
  $url = "$BaseUrl/$Id"
  Write-Host "--- DELETE $url ---" -ForegroundColor Cyan
  try {
    $r = Invoke-WebRequest -Uri $url -Method Delete
    if ($r.StatusCode -eq 204) {
      Write-Host "Eliminado (204 No Content)" -ForegroundColor Green
    } else {
      Write-Response $r
    }
  } catch {
    if ($_.Exception -and $_.Exception.Response -and $_.Exception.Response.StatusCode -eq 204) {
      Write-Host "Eliminado (204 No Content)" -ForegroundColor Green
    } else {
      Write-ErrorBody $_
    }
  }
}

switch ($Command) {
  "list"   { Invoke-List }
  "get"    { Invoke-Get }
  "create" { if (-not $Name) { $Name = "Producto" }; Invoke-Create }
  "update" { Invoke-Update }
  "delete" { Invoke-Delete }
  default  { Show-Usage }
}