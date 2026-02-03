# Calculator Module for Ralph Demo

function Add-Numbers {
    param([double]$a, [double]$b)
    return $a + $b
}

function Subtract-Numbers {
    param([double]$a, [double]$b)
    return $a - $b
}

function Multiply-Numbers {
    param([double]$a, [double]$b)
    return $a * $b
}

function Divide-Numbers {
    param([double]$a, [double]$b)
    if ($b -eq 0) {
        throw "Cannot divide by zero"
    }
    return $a / $b
}

Export-ModuleMember -Function Add-Numbers, Subtract-Numbers, Multiply-Numbers, Divide-Numbers
