sudo kubectl create namespace mr-do-player
sudo kubectl apply -f mr-do-player-pv.yml
sudo kubectl apply -f mr-do-player-pvc.yml
sudo kubectl create configmap mr-do-snapserver-cfgmap --from-file=etc/snapserver.conf -n mr-do-player
# sudo kubectl get configmap mr-do-snapserver-cfgmap -o yaml
sudo kubectl create configmap mr-do-asound-cfgmap --from-file=etc/asound.conf -n mr-do-player
# sudo kubectl get configmap mr-do-asound-cfgmap -o yaml
sudo kubectl apply -f mr-do-player-service.yml
sudo kubectl apply -f mr-do-player-deployment.yml
#sudo kubectl apply -f mr-do-player-ingress.yml

sudo kubectl describe pod mr-do-player -n mr-do-player
sudo kubectl get pods -n mr-do-player -o wide
sudo kubectl get pods --all-namespaces -o wide



#sudo kubectl get ingress --all-namespaces -o wide
#sudo kubectl describe ingress -n mr-do-player

sudo kubectl get pv --all-namespaces -o wide
sudo kubectl get pvc --all-namespaces -o wide


sudo kubectl describe pv mr-do-player-pv-data -n mr-do-player
sudo kubectl describe pvc mr-do-player-pvc-data -n mr-do-player

sudo kubectl get configmap --all-namespaces -o wide

sudo kubectl get svc --all-namespaces
sudo kubectl get services  -n mr-do-player -o wide
sudo kubectl describe services mr-do-player-service -n mr-do-player

sudo kubectl get all -n mr-do-player

