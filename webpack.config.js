var webpack = require("webpack");
var path = require('path')
const ENV = process.env.NODE_ENV || 'development';
// console.log('env: ',ENV);

var cfg = {

	devtool: 'source-map',

	module: {
		loaders: [
			{ test: /\.json$/, loader: 'json-loader'},
			{ test: /\.coffee$/, loader: "coffee-loader" },
			{ test: /\.(xml|html|txt|md|svg|glsl)$/, loader: "raw-loader" },
			{ test: /\.scss$/, loader: 'style-loader!css-loader!sass-loader' },
			{ test: /\.css$/, loader: 'style-loader!css-loader' },
			{test: /\.(png|jpg|gif|svg|eot|ttf|woff|woff2)$/,loader: 'url-loader',options: {limit: 10000}}
		]
	},

	entry: {
		main: path.resolve(__dirname,"client-source/app.coffee"),
	},

	resolve: {
		"alias": {
			"react" : "preact-compat",
			"react-dom": "preact-compat",
			"re": "preact",
			
		}
	},

	output: {
		path: path.resolve(__dirname,'client-static'),
		publicPath: path.resolve(__dirname,'client-static'),
		filename: "[name].bundle.js"
	},
	devServer: {
		// host : '192.168.1.6',
		port: 1338,
		host: '192.168.1.4',
		publicPath: '/',
		contentBase: path.resolve(__dirname,'client-static')
	}

}



module.exports = cfg;
