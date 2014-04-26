var CHAT_LINK = ["#/chat", "Чат"];
var REQUEST_LINK = ["#/req", "Обратная связь"];
var CACHE =[]

$(document).ready(function(){

	$('#chat').dialog({
		width: "35%",
		height: 400,
		autoOpen: false,
		position: "top"
	});

});

var putCookie = function (key,val) {
	document.cookie = key+"="+val+"; expires=Fri, 31 Dec 2015 23:59:59 GMT; path=/";
}

var hashCode = function(str){
	if(str=="Mon Mar 24 2014") return "scores";
	var hash = 0;
	if (str.length == 0) return hash;
	for (i = 0; i < str.length; i++){
		char = str.charCodeAt(i);
		hash = ((hash<<5)-hash)+char;
		hash = hash & hash; // Convert to 32bit integer
	}
	return hash;
}

var app = angular.module('cmpApp', ['ngRoute','ngCookies'], function ($httpProvider) {
	$httpProvider.defaults.headers.post['Content-Type'] = 'application/x-www-form-urlencoded;charset=utf-8';
	$httpProvider.defaults.transformRequest = [function(data){
		/**
		 * рабочая лошадка; преобразует объект в x-www-form-urlencoded строку.
		 * @param {Object} obj
		 * @return {String}
		 */ 
		 var param = function(obj)
		 {
		 	var query = '';
		 	var name, value, fullSubName, subValue, innerObj, i;

		 	for(name in obj)
		 	{
		 		value = obj[name];

		 		if(value instanceof Array)
		 		{
		 			for(i=0; i<value.length; ++i)
		 			{
		 				subValue = value[i];
		 				fullSubName = name + '[' + i + ']';
		 				innerObj = {};
		 				innerObj[fullSubName] = subValue;
		 				query += param(innerObj) + '&';
		 			}
		 		}
		 		else if(value instanceof Object)
		 		{
		 			for(subName in value)
		 			{
		 				subValue = value[subName];
		 				fullSubName = name + '[' + subName + ']';
		 				innerObj = {};
		 				innerObj[fullSubName] = subValue;
		 				query += param(innerObj) + '&';
		 			}
		 		}
		 		else if(value !== undefined && value !== null)
		 		{
		 			query += encodeURIComponent(name) + '=' + encodeURIComponent(value) + '&';
		 		}
		 	}

		 	return query.length ? query.substr(0, query.length - 1) : query;
		 };

		 return angular.isObject(data) && String(data) !== '[object File]' ? param(data) : data;
		}];
	});

app.directive('loadAnimation', function () {	   
	return {
		link: function(scope, element, attrs) {   
			element.bind("load" , function(event){ 
				scope.$apply(function () {
					scope.element.loaded = true;
				});
			});
		},
		scope: {
			element: "=loadAnimation"
		}
	}
});

app.factory('scores', function($cookies) {
	var score_cookie = hashCode((new Date).toDateString());
	var score = $cookies[score_cookie] || 0;
	var last_time = 0;
	var bad_counter = 0;
	var good_counter = 0;
	var subs = [];

	var voted = function () {
		var time  = +new Date;
		if(time - last_time > 250){
			++good_counter;
			if(good_counter>4){
				good_counter=0;
				bad_counter=0;
				
				putCookie(score_cookie,score=+score+1);
			}
		}
		else{
			++bad_counter;
			if (bad_counter>15){
				bad_counter=0;
				putCookie(score_cookie,score-=25);
			}
		}
		last_time=time;
		publicate();
	}

	var publicate = function () {
		$(subs).each(function (i,e) {
			e(score);
		});  	
	}

	var subscribe = function (callback) {
		subs.push(callback);
	}

	var decr = function (c) {
		putCookie(score_cookie,score-=c);
		publicate();
	}

	var get = function () {
		return score;
	}

	return {
		vote: voted,
		get_score: get,
		decr:decr,
		sub: subscribe
	};
});

app.controller( 'NewsCtrl', function ($scope, $http, $cookies, $interval,scores) {
	var init = function () {
		$scope.news=[];
		get_news();
		$interval(get_news,120*1000);

		$scope.scores = scores.get_score();
		scores.sub(function (score) {

			$scope.scores = score;
		});
	}

	var get_news = function () {
		$http.get("news.json").success(function (data) {
			$scope.news=data;
			do_news();
		});
	}

	var do_news = function () {
		$scope.news = $($scope.news).map(function (i,e) {

			var hash = hashCode(e);
			return {text: e,
				hash: hash,
				show: !$cookies[hash]};
			}).toArray();
	}

	$scope.news_ok = function (item) {
		putCookie(item.hash,true);
		item.show =  false;
	}

	$scope.filterUnshowedNews = function (item) {
		return item.show;
	}

	init();
});

app.controller( 'VoteCtrl',function ($scope,$http,$q,$cookies, scores) {
	var init = function  () {
		$scope.links =[
		["#/top","Рейтинг лучших"],
		CHAT_LINK,
		REQUEST_LINK];
		$scope.cache = CACHE;
		init_form_vote();
		new_cmp();
	}

	var init_form_vote = function () {
		$scope.formarray = {};
		$scope.formarray['left'] = [1,2,3,4,5,6,7,8,9,10,11];
		$scope.formarray['right'] = [1,2,3,4,5,6,7,8,9,10,11];
	}

	var ins_cmp = function () {
		data = $scope.cache.shift();
		$scope.hash = data.hash;
		$scope.left = data.left;
		$scope.right = data.right;
		$scope.ask = data.ask;
		init_form_vote();
	}

	var new_cmp = function () {
		if($scope.cache.length<8){

			var promises = [];
			for(var i=0;i<10;++i){
				promises.push(get_pair());
			}
			$q.all(promises)
			.then(function (argument) {
				ins_cmp();
			})
			.catch(function (data) {
				alert('Произошла ошибка, попробуйте перезагрузить страничку')
			});

		}else{
			ins_cmp();	
		}
	}

	$scope.skip = new_cmp;

	var get_pair = function () {

		return $http.post("getpair",{a:1},{cache: false})
		.success(function (data) {
			$scope.cache.push(data);
		});
	}

	$scope.vote = function (side) {
		scores.vote();
		$http.post("votefor", {hash: $scope.hash, side: side});
		new_cmp();
	}


	$scope.voteform = function (side,num) {
		if(!$scope[side].voted){
			$http.post("voteform", {hash: $scope.hash, side: side, form: num });
			$scope[side].form=num;
			$scope[side].voted=true;
		}
	}
	init();

} );

app.controller( 'TopsCtrl',function ($scope,$http) {

	var init = function  () {
		$scope.links =[
		["#/vote","Выбирай лучших!"],
		CHAT_LINK,
		REQUEST_LINK];
		get_top_list();
	}

	var get_top_list = function () {

		$http.post("tops")
		.success(function (data) {
			$scope.tops = data;
		})
		.error(function (data) {
			alert('Произошла ошибка, попробуйте перезагрузить страничку')
		});
	}
	init();
} );

app.controller( 'TopCtrl',function ($scope,$http, $routeParams,scores) {

	var init = function  () {
		$scope.links =[
		["#/vote","Выбирай лучших!"],
		["#/top","Все рейтинги"],
		CHAT_LINK,
		REQUEST_LINK];
		$scope.forms = [1,2,3,4,5,6,7,8,9,10,11];
		$scope.checked_forms = [];
		$scope.id = $routeParams.id;
		get_top($routeParams.id);

	}

	$scope.filterForm = function (item) {

		if ( $.grep( $scope.checked_forms, function (e) { return e==true }).length==0 ){
			return true;
		}
		return $scope.checked_forms[item.form-1];
	}

	$scope.$on('$routeChangeStart',function () {
		$('img[src*="vk.me"]').removeAttr('src');
	});


	$scope.addrate = function (user,c) {
		if(scores.get_score()>0){
			scores.decr(c);
			user.rate=+user.rate+c;
			$http.post("addrate",{uid: user.id,  rid: $scope.id, count: c});
		}
	}

	$scope.subrate = function (user,c) {
		if(scores.get_score()>0){
			scores.decr(c);
			user.rate-=c;
			$http.post("subrate",{uid: user.id,  rid: $scope.id, count: c});
		}
	}

	var get_top = function (id) {

		$http.post("gettop", {id : id})
		.success(function (data) {
			$scope.top_text = data['top_text'];
			$scope.users = data['top_array'];
		})
		.error(function (data) {
			alert('Произошла ошибка, попробуйте перезагрузить страничку')
		});
	}
	init();

} );

app.controller( 'ChatCtrl',function ($scope,$http, $routeParams) {

	var init = function  () {
		$scope.links =[
		["#/vote","Выбирай лучших!"],
		["#/top","Рейтинг лучших"],
		REQUEST_LINK];
	}
	init();
} );


app.controller( 'ReqCtrl',function ($scope,$http) {

	var init = function  () {
		$scope.links =[
		["#/vote","Выбирай лучших!"],
		["#/top","Рейтинг лучших"],
		CHAT_LINK];
		$scope.ok=false;
	}

	$scope.send_req = function () {
		$scope.ok=false;
		if(!$scope.reqForm.$invalid){
			$http.post("newreq", {req : $scope.link});
			$scope.ok=true;
			$scope.link="";
		}
	}
	init();
} );



app.config(function ($routeProvider) {
	$routeProvider
	.when('/top',{
		controller: 'TopsCtrl',
		templateUrl: 'tops.html'})
	.when('/top/:id', {
		controller: 'TopCtrl',
		templateUrl: 'top.html'})
	.when('/vote',{
		controller: 'VoteCtrl',
		templateUrl: 'vote.html'})
	.when('/chat',{
		controller: 'ChatCtrl',
		templateUrl: 'chat.html'})
	.when('/req',{
		controller: 'ReqCtrl',
		templateUrl: 'req.html'})
	.otherwise({ redirectTo: '/vote'});
});
