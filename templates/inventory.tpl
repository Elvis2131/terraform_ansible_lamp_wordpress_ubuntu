[instances]
%{ for instance in instances ~}
${instance}
%{ endfor ~}