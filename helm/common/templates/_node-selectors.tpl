### Mina node selector TEMPLATES ###

{{/*
Node selector: spot node affinity
*/}}
{{- define "nodeSelector.preemptible" }}
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
          - key: "cloud.google.com/gke-spot"
            {{- if .nodeSelector.preemptible }}
            operator: In
            {{- else }}
            operator: NotIn
            {{- end }}
            values: ["true"]
{{- end }}

{{/*
Node selector: custom affinity mapping
*/}}
{{- define "nodeSelector.customMapping" }}
{{- if . }}
nodeSelector:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end }}
