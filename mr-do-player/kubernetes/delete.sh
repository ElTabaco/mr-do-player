kubectl delete -f mr-do-player-deployment.yml
kubectl delete -f mr-do-player-service.yml
kubectl delete configmap mr-do-asound-cfgmap -n mr-do-player
# kubectl delete configmap mr-do-kodi-cfgmap -n mr-do-player
kubectl delete configmap mr-do-snapserver-cfgmap -n mr-do-player
kubectl delete -f mr-do-player-pvc.yml
kubectl delete -f mr-do-player-pv.yml
# kubectl delete -f mr-do-player-ingress.yml
# kubectl delete all,deployment,configmap,pv,pvc --all -n mr-do-player
kubectl delete namespace mr-do-player
