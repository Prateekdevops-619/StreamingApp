{{- define "streamingapp.imageTag" -}}
{{- .Values.global.imageTag -}}
{{- end }}

{{- define "streamingapp.ecrImage" -}}
{{- printf "%s/%s:%s" .Values.global.ecrBase .service .Values.global.imageTag -}}
{{- end }}

{{- define "streamingapp.mongoUri" -}}
mongodb://mongodb-service:27017/streamingapp
{{- end }}
