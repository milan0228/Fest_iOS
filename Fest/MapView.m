//
//  MapViewController.m
//  Miller
//
//  Created by kadir pekel on 2/7/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MapView.h"
#import "CallOutAnnotationView.h"
#import "CalloutMapAnnotation.h"

#define Key(Val) [NSString stringWithFormat:@"%lf",Val]
#define Keys(Val1,Val2) [NSString stringWithFormat:@"%lf,%lf",Val1,Val2]


@interface MapView()

@property (nonatomic,strong) CalloutMapAnnotation *calloutAnnotation;
-(NSMutableArray *)decodePolyLine: (NSMutableString *)encoded;
-(void) updateRouteView;
-(NSArray*) calculateRoutesFrom:(CLLocationCoordinate2D) from to: (CLLocationCoordinate2D) to;
-(void) centerMap;


@end

@implementation MapView

@synthesize lineColor,mapView;

PlaceMark* from,*to;

- (id) initWithFrame:(CGRect) frame
{
	self = [super initWithFrame:frame];
	if (self != nil) {
		mapView = [[MKMapView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
		//mapView.showsUserLocation = YES;
		[mapView setDelegate:self];
		
		routeView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, mapView.frame.size.width, mapView.frame.size.height)];
		routeView.userInteractionEnabled = NO;
        
        mapView.mapType = MKMapTypeStandard;
        
		[mapView addSubview:routeView];
		
		self.lineColor = [UIColor blueColor];
        
        [self addSubview:mapView];
	}
    
	return self;
}


-(NSMutableArray *)decodePolyLine: (NSMutableString *)encoded {
	[encoded replaceOccurrencesOfString:@"\\\\" withString:@"\\"
								options:NSLiteralSearch
								  range:NSMakeRange(0, [encoded length])];
	NSInteger len = [encoded length];
	NSInteger index = 0;
	NSMutableArray *array = [[NSMutableArray alloc] init];
	NSInteger lat=0;
	NSInteger lng=0;
	while (index < len) {
		NSInteger b;
		NSInteger shift = 0;
		NSInteger result = 0;
		do {
			b = [encoded characterAtIndex:index++] - 63;
			result |= (b & 0x1f) << shift;
			shift += 5;
		} while (b >= 0x20);
		NSInteger dlat = ((result & 1) ? ~(result >> 1) : (result >> 1));
		lat += dlat;
		shift = 0;
		result = 0;
		do {
			b = [encoded characterAtIndex:index++] - 63;
			result |= (b & 0x1f) << shift;
			shift += 5;
		} while (b >= 0x20);
		NSInteger dlng = ((result & 1) ? ~(result >> 1) : (result >> 1));
		lng += dlng;
		NSNumber *latitude = [[NSNumber alloc] initWithFloat:lat * 1e-5];
		NSNumber *longitude = [[NSNumber alloc] initWithFloat:lng * 1e-5];
		//printf("[%f,", [latitude doubleValue]);
		//printf("%f]", [longitude doubleValue]);
		CLLocation *loc = [[CLLocation alloc] initWithLatitude:[latitude floatValue] longitude:[longitude floatValue]];
		[array addObject:loc];
	}
	
	return array;
}

-(NSArray*) calculateRoutesFrom:(CLLocationCoordinate2D) f to: (CLLocationCoordinate2D) t
{
	NSString* saddr = [NSString stringWithFormat:@"%f,%f", f.latitude, f.longitude];
	NSString* daddr = [NSString stringWithFormat:@"%f,%f", t.latitude, t.longitude];
	
	NSString* apiUrlStr = [NSString stringWithFormat:@"http://maps.google.com/maps?output=dragdir&saddr=%@&daddr=%@", saddr, daddr];
	NSURL* apiUrl = [NSURL URLWithString:apiUrlStr];
	NSLog(@"api url: %@", apiUrl);
	NSString *apiResponse = [NSString stringWithContentsOfURL:apiUrl encoding:NSASCIIStringEncoding error:nil];//[NSString stringWithContentsOfURL:apiUrl];
	NSString* encodedPoints = [apiResponse stringByMatching:@"points:\\\"([^\\\"]*)\\\"" capture:1L];
	
	return [self decodePolyLine:[encodedPoints mutableCopy]];
}

-(void) centerMap
{
	MKCoordinateRegion region;
    
	CLLocationDegrees maxLat = -90;
	CLLocationDegrees maxLon = -180;
	CLLocationDegrees minLat = 90;
	CLLocationDegrees minLon = 180;
	for(int idx = 0; idx < routes.count; idx++)
	{
		CLLocation* currentLocation = [routes objectAtIndex:idx];
		if(currentLocation.coordinate.latitude > maxLat)
			maxLat = currentLocation.coordinate.latitude;
		if(currentLocation.coordinate.latitude < minLat)
			minLat = currentLocation.coordinate.latitude;
		if(currentLocation.coordinate.longitude > maxLon)
			maxLon = currentLocation.coordinate.longitude;
		if(currentLocation.coordinate.longitude < minLon)
			minLon = currentLocation.coordinate.longitude;
	}
	region.center.latitude     = (maxLat + minLat) / 2;
	region.center.longitude    = (maxLon + minLon) / 2;
    //region.span.latitudeDelta  = 0.1;
    //region.span.longitudeDelta = 0.1;
	region.span.latitudeDelta  = maxLat - minLat;
	region.span.longitudeDelta = maxLon - minLon;
	
    if(region.center.latitude!=0 && region.center.longitude!=0){
        [mapView setRegion:region animated:YES];
        //[mapView regionThatFits:region];
    }
    else
    {
        [mapView setRegion:MKCoordinateRegionForMapRect(MKMapRectWorld) animated:YES];
    }
	
}

-(void) showRouteFrom: (Place*) f to:(Place*) t
{
	
	if(routes)
    {
		[mapView removeAnnotations:[mapView annotations]];
	}
	
    from = [[PlaceMark alloc] initWithPlace:f];
    to = [[PlaceMark alloc] initWithPlace:t];
    
    //SetValue_Key(f.name, Keys(f.latitude,f.longitude));
    //SetValue_Key(t.name, Keys(t.latitude,t.longitude));
    
    //NSLog(@"F.Name=>%@",f.name);
    //NSLog(@"T.Name=>%@",t.name);
    
    SetValue_Key(f.name, Key(f.longitude));
    SetValue_Key(t.name, Key(t.longitude));
    
	[mapView addAnnotation:from];
	[mapView addAnnotation:to];
	
	routes = [self calculateRoutesFrom:from.coordinate to:to.coordinate];
	
	[self updateRouteView];
	[self centerMap];
    
}

-(void) updateRouteView {
	CGContextRef context = 	CGBitmapContextCreate(nil,
												  routeView.frame.size.width,
												  routeView.frame.size.height,
												  8,
												  4 * routeView.frame.size.width,
												  CGColorSpaceCreateDeviceRGB(),
												  (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
	
	CGContextSetStrokeColorWithColor(context, lineColor.CGColor);
	CGContextSetRGBFillColor(context, 0.0, 0.0, 1.0, 1.0);
	CGContextSetLineWidth(context, 3.0);
	
	for(int i = 0; i < routes.count; i++) {
		CLLocation* location = [routes objectAtIndex:i];
		CGPoint point = [mapView convertCoordinate:location.coordinate toPointToView:routeView];
		
		if(i == 0) {
			CGContextMoveToPoint(context, point.x, routeView.frame.size.height - point.y);
		} else {
			CGContextAddLineToPoint(context, point.x, routeView.frame.size.height - point.y);
		}
	}
	
	CGContextStrokePath(context);
	
	CGImageRef image = CGBitmapContextCreateImage(context);
	UIImage* img = [UIImage imageWithCGImage:image];
	
	routeView.image = img;
	CGContextRelease(context);
    
}

#pragma mark mapView delegate functions

- (MKAnnotationView *) mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>) annotation {
    
    if ([annotation isKindOfClass:[CalloutMapAnnotation class]]) {
        
        CallOutAnnotationView *annotationView = (CallOutAnnotationView *)[self.mapView dequeueReusableAnnotationViewWithIdentifier:@"CalloutView"];
        
        if (!annotationView)
        {
            annotationView = [[CallOutAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"CalloutView"];
        }
        
        for(UIView *view in annotationView.contentView.subviews)
        {
            [view removeFromSuperview];
        }
        
        UILabel *lblDescrip = [[UILabel alloc] initWithFrame:CGRectMake(2.5, 2, 235, 60)];
        lblDescrip.textColor = [UIColor whiteColor];
        lblDescrip.textAlignment = NSTextAlignmentCenter;
        lblDescrip.lineBreakMode = NSLineBreakByWordWrapping;
        lblDescrip.font = [UIFont fontWithName:ProximaNovaRegular size:14.0];
        lblDescrip.numberOfLines = 3;
        [annotationView.contentView addSubview:lblDescrip];
        lblDescrip.text = [NSString stringWithFormat:@"%@",GetValue_Key(Key(_calloutAnnotation.coordinate.longitude))];
        
        return annotationView;
	}
    else if ([annotation isKindOfClass:[PlaceMark class]])
    {
        allocUserDefault;
        
        NSString *title_1 = getUserDefault(@"fAdd");
        NSString *title_2 = getUserDefault(@"tAdd");
        
        //Giving custom images to annotation pins//
        MKPinAnnotationView *annView=[[MKPinAnnotationView alloc]
                                      initWithAnnotation:annotation reuseIdentifier:@"pin"];
        
        if([[annView.annotation title] isEqualToString:title_1])
        {
            annView.image=[UIImage imageNamed:@"icon_pin"];
            annView.canShowCallout=NO;
        }
        else if ([[annView.annotation title] isEqualToString:title_2])
        {
            annView.image=[UIImage imageNamed:@"icon_pin_red"];
            annView.canShowCallout=NO;
        }
        
        return annView;
    }
    
    return nil;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
	if ([view.annotation isKindOfClass:[PlaceMark class]])
    {
        if (_calloutAnnotation.coordinate.latitude == view.annotation.coordinate.latitude&&
            _calloutAnnotation.coordinate.longitude == view.annotation.coordinate.longitude) {
            return;
        }
        //if (_calloutAnnotation) {
            [self.mapView removeAnnotation:_calloutAnnotation];
            _calloutAnnotation = nil;
        //}
        _calloutAnnotation = [[[CalloutMapAnnotation alloc]
                               initWithLatitude:view.annotation.coordinate.latitude
                               andLongitude:view.annotation.coordinate.longitude] autorelease];
        [self.mapView addAnnotation:_calloutAnnotation];
        
        [self.mapView setCenterCoordinate:_calloutAnnotation.coordinate animated:YES];
	}
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view
{
    if (_calloutAnnotation&& ![view isKindOfClass:[CallOutAnnotationView class]])
    {
        if (_calloutAnnotation.coordinate.latitude == view.annotation.coordinate.latitude&&
            _calloutAnnotation.coordinate.longitude == view.annotation.coordinate.longitude) {
            [self.mapView removeAnnotation:_calloutAnnotation];
            _calloutAnnotation = nil;
        }
    }
}

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
{
	routeView.hidden = YES;
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
	[self updateRouteView];
	routeView.hidden = NO;
	[routeView setNeedsDisplay];
}


@end
