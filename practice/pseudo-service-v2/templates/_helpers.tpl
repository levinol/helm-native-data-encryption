{{/* Функция для дешифрования переменных с добавлением ID,
состоящего из контура и AES256*/}}
{{- define "decrypter" -}}
{{- $aesKey := index . 0 }}
{{- $contour := index . 1 }}
{{- $vallist := index . 2 }}
{{- $CommonID :=  printf "%s:%s:" $contour "AES256" }}
{{- range $key, $val := $vallist }}
{{- if hasPrefix $CommonID $val }}
{{ $key }}: {{ ( trimPrefix $CommonID  $val) | decryptAES $aesKey }}
{{- else }}
{{ $key }}: {{ $val }}
{{- end }}
{{- end -}}
{{- end -}}