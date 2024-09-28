functions -q argparse
if test $status -ne 0
	echo "Error: argparse not found. Please upgrade your fish shell."
	return 1
end

argparse 'q=+' 'r' 'chrome' 'firefox' -- $argv
or return 1

set -f http_verb "GET"
set -f url ""
set -f query_params
set -f headers
set -f user_agent ""
set -f random_user_agent 0
set -f capture_file ""
set -f extra_curl_args

# Handle options
if set -q _flag_q
	set query_params $query_params $_flag_q
end

if set -q _flag_r
	set random_user_agent 1
end

if set -q _flag_chrome
	set user_agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.63 Safari/537.36"
end

if set -q _flag_firefox
	set user_agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:92.0) Gecko/20100101 Firefox/92.0"
end

# Positional arguments in $argv
if test (count $argv) -ge 2
	set http_verb $argv[1]
	set url $argv[2]
	set extra_curl_args $argv[3..-1]
else if test (count $argv) -eq 1
	set url $argv[1]
end

# Build the curl command
set -l curl_cmd curl

# Set method
if test $http_verb != "GET"
	set curl_cmd $curl_cmd -X $http_verb
end

# Handle query parameters
if test (count $query_params) -gt 0
	set -l query_string (string join '&' $query_params)
	if string match -qr '\?' -- $url
		set url "$url&$query_string"
	else
		set url "$url?$query_string"
	end
end

# Handle random user agent
if test $random_user_agent -eq 1
	# A simple list of user agents
	set user_agents "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" "Mozilla/5.0 (X11; Linux x86_64)"
	set user_agent $user_agents[(math (random) % (count $user_agents) + 1)]
end

# Set user agent
if test -n "$user_agent"
	set curl_cmd $curl_cmd -H "User-Agent: $user_agent"
end

# Handle CREST_HEADER_* environment variables
for var_name in (env | string match -r '^CREST_HEADER_(.+)')
	set header_name (string replace -r '^CREST_HEADER_' '' -- $var_name)
	set header_value (eval echo \$$var_name)
	set headers $headers "-H" "$header_name: $header_value"
end

# Add headers to curl command
if test (count $headers) -gt 0
	set curl_cmd $curl_cmd $headers
end

# Add any extra curl arguments
if test (count $extra_curl_args) -gt 0
	set curl_cmd $curl_cmd $extra_curl_args
end

# Finally, add the URL
set curl_cmd $curl_cmd $url

# Echo the actual executed curl command
echo "Executing:" (string escape -- $curl_cmd)

# Execute the curl command and capture output and headers
set -l response_file (mktemp)
set -l headers_file (mktemp)
eval $curl_cmd --include --silent --output $response_file --dump-header $headers_file

# Read headers and body
set -l headers (cat $headers_file)
set -l body (cat $response_file)

# Get the HTTP status code
set -l http_status (printf '%s\n' $headers | grep -m1 '^HTTP/' | awk '{print $2}')

# Get the Content-Type header
set -l content_type (printf '%s\n' $headers | grep -i '^Content-Type:' | cut -d' ' -f2- | tr -d '\r')

# If content type is JSON or something that jq supports, beautify it
if string match -qr 'application/(json|.*\+json)' -- $content_type
	printf '%s\n' $body | jq --color-output
else
	printf '%s\n' $body
end

# If response is 2xx, save the request in OpenAPI format
if test $http_status -ge 200 -a $http_status -lt 300
	# Determine capture file
	if set -q CREST_API_CAPTURE
		set capture_file $CREST_API_CAPTURE
	else
		set capture_file ~/.local/crest/(string replace -r 'https?://' '' -- $url | string split '/' | head -n1).json
	end

	# Build OpenAPI entry
	set -l method (string lower $http_verb)
	set -l path (string replace -r 'https?://[^/]*' '' -- $url | string split '?' | head -n1)
	if test -z "$path"
		set path "/"
	end

	# Ensure the capture directory exists
	mkdir -p (dirname $capture_file)

	# Append to the OpenAPI JSON file
	set -l openapi_entry "{
\"paths\": {
\"$path\": {
	\"$method\": {
	\"responses\": {
		\"$http_status\": {
		\"description\": \"\"
		}
	}
	}
}
}
}"
	echo $openapi_entry | jq -s '.[0] * .[1]' $capture_file - > $capture_file.tmp
	mv $capture_file.tmp $capture_file
end

# Clean up temporary files
rm $response_file $headers_file
