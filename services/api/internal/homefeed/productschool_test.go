package homefeed

import "testing"

func TestParseProductSchoolListing(t *testing.T) {
	html := `<a aria-label="Agentic Architecture" href="/blog/artificial-intelligence/agentic-architecture">Read</a>
<a aria-label="Product Planning" href="/blog/product-fundamentals/product-planning">Read</a>
<a aria-label="Not a post" href="/resources">Read</a>`

	posts := ParseProductSchoolListing([]byte(html))
	if len(posts) != 2 {
		t.Fatalf("posts = %d, want 2", len(posts))
	}
	if posts[0].ExternalID != "artificial-intelligence/agentic-architecture" {
		t.Fatalf("external id = %q", posts[0].ExternalID)
	}
	if posts[0].Role != "Artificial Intelligence" {
		t.Fatalf("role = %q", posts[0].Role)
	}
	if posts[0].URL != "https://productschool.com/blog/artificial-intelligence/agentic-architecture" {
		t.Fatalf("url = %q", posts[0].URL)
	}
}

func TestParseIndieHackersListing(t *testing.T) {
	document := `<div class="story homepage-post">
<a class="story__text-link story__link-element" href="/post/building-a-product-abc123"><h3 class="story__title">Building a Product &amp; Finding Users</h3></a>
<div class="story__byline"><span class="user-link__name user-link__name--username">maker_one</span></div>
<a class="story__count story__count--likes"><span class="story__count-number">42</span></a>
<a class="story__count story__count--comments"><span class="story__count-number">7</span></a>
</div>`

	posts := ParseIndieHackersListing([]byte(document))
	if len(posts) != 1 {
		t.Fatalf("posts = %d, want 1", len(posts))
	}
	post := posts[0]
	if post.Source != "indiehackers" || post.ExternalID != "post/building-a-product-abc123" {
		t.Fatalf("identity = %q/%q", post.Source, post.ExternalID)
	}
	if post.Content != "Building a Product & Finding Users" || post.Author != "maker_one" {
		t.Fatalf("content/author = %q/%q", post.Content, post.Author)
	}
	if post.URL != "https://www.indiehackers.com/post/building-a-product-abc123" {
		t.Fatalf("url = %q", post.URL)
	}
}
