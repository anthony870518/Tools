import http.client
import json
import urllib.parse
from datetime import datetime
import dateutil.tz

def lambda_handler(event, context): 

    # List of cities to query, with corresponding names
    city_map = {
        "26": "Delft",
        "90": "Den Haag",
        "6224": "Rotterdam"
        #"616": "Haarlem",
        #"24": "Amsterdam",
        #"320": "Arnhem",
        #"619": "Capelle aan den IJssel",
        #"26": "Delft",
        #"28": "Den Bosch",
        #"90": "Den Haag",
        #"110": "Diemen",
        #"620": "Dordrecht",
        #"29": "Eindhoven",
        #"545": "Groningen",
        #"616": "Haarlem",
        #"6099": "Helmond",
        #"6209": "Maarssen",
        #"6090": "Maastricht",
        #"6051": "Nieuwegein",
        #"6217": "Nijmegen",
        #"25": "Rotterdam",
        #"6224": "Rijswijk",
        #"6211": "Sittard",
        #"6093": "Tilburg",
        #"27": "Utrecht",
        #"6145": "Zeist",
        #"6088": "Zoetermeer"
    }
    cities = list(city_map.keys())

    # Headers for the API request
    headers = {
        "Accept": "*/*",
        "User-Agent": "Thunder Client (https://www.thunderclient.com)",
        "Content-Type": "application/json"
    }
    
    # Function to query the API for a specific city
    def fetch_city_data(city_code):
        conn = http.client.HTTPSConnection("api.holland2stay.com")
        
        # Payload with the GraphQL query, adjusting the city code
        payload = json.dumps({
            "operationName": "GetCategories",
            "variables": {
                "currentPage": 1,
                "id": "Nw==",
                "filters": {
                    "available_to_book": {"eq": "179"},
                    "city": {"eq": city_code},  # Adjusting city code here
                    "category_uid": {"eq": "Nw=="}
                },
                "pageSize": 50,
                "sort": {"available_startdate": "ASC"}
            },
            "query": """query GetCategories($id: String!, $pageSize: Int!, $currentPage: Int!, $filters: ProductAttributeFilterInput!, $sort: ProductAttributeSortInput) {
                categories(filters: {category_uid: {in: [$id]}}) {
                    items {
                        uid
                        ...CategoryFragment
                        __typename
                    }
                    __typename
                }
                products(
                    pageSize: $pageSize,
                    currentPage: $currentPage,
                    filter: $filters,
                    sort: $sort
                ) {
                    ...ProductsFragment
                    __typename
                }
            }
        
            fragment CategoryFragment on CategoryTree {
                uid
                meta_title
                meta_keywords
                meta_description
                __typename
            }
        
            fragment ProductsFragment on Products {
                items {
                    name
                    city
                    offer_text
                    offer_text_two
                    __typename
                }
                __typename
            }"""
        })
        
        # Sending request
        conn.request("POST", "/graphql/", payload, headers)
        response = conn.getresponse()
        data = response.read().decode("utf-8")
        
        # Parsing JSON response
        return json.loads(data)

    # Function to send a notification via LINE API
    def linenoti(message):
        try:
            encoded_message = urllib.parse.quote(message)
            lineconn = http.client.HTTPSConnection("notify-api.line.me")
            headersList = {
              "Accept": "*/*",
              "User-Agent": "Thunder Client (https://www.thunderclient.com)",
              "Authorization": "Bearer xxxxxxxxxxxxxxxxxx" 
            } 
            lineconn.request("POST", f"/api/notify?message={encoded_message}", "", headersList)
            response = lineconn.getresponse()
            result = response.read()
            print("Notification response:", result.decode("utf-8"))
        except Exception as e:
            print("Failed to send notification:", e)

    # Aggregating product details from multiple cities
    all_product_details = []
    
    for city in cities:
        json_data = fetch_city_data(city)
        try:
            # Extracting product details with name, city, offer_text, and offer_text_two
            product_details = [
                f"City: {city_map.get(str(item['city']), 'Unknown')}, Name: {item['name']}, Notes: {item.get('offer_text', 'N/A')}, {item.get('offer_text_two', 'N/A')}"
                for item in json_data['data']['products']['items']
                if item.get('offer_text_two', 'N/A') != "Housing permit required"  # Exclude specific items
            ]
            #product_details = [
            #    f"City: {city_map.get(str(item['city']), 'Unknown')}, Name: {item['name']}, Notes: {item.get('offer_text', 'N/A')}, {item.get('offer_text_two', 'N/A')}"
            #    for item in json_data['data']['products']['items']
            #]
            #if item['name'] not in ["Kasteellaan 73", "Kasteellaan 85"]  # Exclude specific properties if needed
            all_product_details.extend(product_details)  # Add to the aggregated list
        except KeyError as e:
            print(f"Error accessing data for city {city}: {e}")
            linenoti(f"Error accessing data for city {city}")

    # After collecting data for all cities
    if all_product_details:  # Check if the list is not empty
        print("Product Details from all cities:")
        print(all_product_details)
    
        # Create a message string from product details
        message = "\nAvailable residences:\n" + "\n".join(all_product_details)
        linenoti(message)
    else:
        message = f"No products found in any city. {list(city_map.values())}"
        print(message)
        singapore_tz = dateutil.tz.gettz('Asia/Singapore')
        now_sgt = datetime.now(tz=singapore_tz)
        if now_sgt.hour == 18 and now_sgt.minute >= 0 and now_sgt.minute < 1:
            print("It's SGT 18:00")
            linenoti(f"BOT is alive for searching residences in these cities: {list(city_map.values())}. \n Exclude: Housing permit required")
        else:
            print("Current time is:", now_sgt.strftime('%H:%M'))

    return 0
