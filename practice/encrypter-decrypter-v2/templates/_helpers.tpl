{{/* Функция для шифрования переменных с добавлением ID,
состоящего из AES256*/}}
{{- define "encrypter" -}}
{{- $aesKey := index . 0 }}
{{- $vallist := index . 1 }}
{{- $CommonID :=  printf "%s:" "AES256" }}
{{- range $key, $val := $vallist }}
{{ $key }}: {{$CommonID}}{{ $val | encryptAES $aesKey }}
{{- end }}
{{- end -}}


{{/* Функция для дешифрования переменных с добавлением ID,
состоящего из AES256*/}}
{{- define "decrypter" -}}
{{- $aesKey := index . 0 }}
{{- $vallist := index . 1 }}
{{- $CommonID :=  printf "%s:" "AES256" }}
{{- range $key, $val := $vallist }}
{{- if hasPrefix $CommonID $val }}
{{ $key }}: {{ ( trimPrefix $CommonID  $val) | decryptAES $aesKey }}
{{- else }}
{{ $key }}: {{ $val }}
{{- end }}
{{- end -}}
{{- end -}}