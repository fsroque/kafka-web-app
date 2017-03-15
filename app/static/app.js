var myApp = angular.module('myApp', []);
 
myApp.controller('myController', function myController($scope) {
    $scope.messages = [];
    console.log('Adding listener.');
    var source = new EventSource('/stream');
    source.addEventListener('message', function(e){
        console.log('Got tweet.');
        $scope.$apply(function() {
            $scope.messages.push(e.data);
        });
    }, false);
    console.log('Added listener.');
});