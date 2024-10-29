sudo kubectl delete -f mr-do-player-deployment.yml
sudo kubectl delete -f mr-do-player-service.yml
sudo kubectl delete configmap mr-do-asound-cfgmap -n mr-do-player
#sudo kubectl delete configmap mr-do-kodi-cfgmap -n mr-do-player
sudo kubectl delete configmap mr-do-snapserver-cfgmap -n mr-do-player
sudo kubectl delete -f mr-do-player-pvc.yml
sudo kubectl delete -f mr-do-player-pv.yml
#sudo kubectl delete -f mr-do-player-ingress.yml
sudo kubectl delete all,deployment,configmap,pv,pvc --all -n mr-do-player
sudo kubectl delete namespace mr-do-player
