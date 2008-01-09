/*

PizzaMain: Demo program for Pizza.
Usage: java PizzaMain numtoppings constraint1 ... constraintN
A constraint has the form [+/-]{desc}[!]
The first character must be either + or -, for pos/neg constraint.
The description is either the name of the topping or a topping type in
all upper-case.  If the constraint ends with a !, it is a mandatory
constraint.

Written by Matthew Sachs, 2006-03-08, for a lecture on unit testing
in Brandeis University's COSI 22a.  Source and lecture notes are released
into the public domain.  c.f. http://www.zevils.com/writings/unit-testing/

*/

import java.util.*;
import Pizza.*;

class PizzaMain {
	public static void main(String args[]) throws Exception {
		PizzaMain pm = new PizzaMain();
		pm.run(args);
	}

	public void run(String args[]) throws Exception {
		Topping allToppings[] = {
			new Topping("mozarella", Topping.CHEESE),
			new Topping("ricotta", Topping.CHEESE),
			new Topping("feta", Topping.CHEESE),
			new Topping("pepperoni", Topping.MEAT),
			new Topping("sausage", Topping.MEAT),
			new Topping("ham", Topping.MEAT),
			new Topping("hamburger", Topping.MEAT),
			new Topping("pineapple", Topping.VEGGIE),
			new Topping("mushrooms", Topping.VEGGIE),
			new Topping("onions", Topping.VEGGIE),
			new Topping("olives", Topping.VEGGIE),
			new Topping("green peppers", Topping.VEGGIE),
			new Topping("roasted garlic", Topping.VEGGIE)
		};
		Pizza.setAllToppings(allToppings);

		Pizza p = new Pizza();
		for(int i = 1; i < args.length; i++) {
			String arg = args[i];
			boolean mandatory = false;
			boolean negative = false;
			int ttype = Topping.NOTYPE;
			int namelen = arg.length();

			if(arg.endsWith("!")) {
				namelen--;
				mandatory = true;
			}

			if(arg.startsWith("+")) {
				negative = false;
			} else if(arg.startsWith("-")) {
				negative = true;
			} else {
				System.err.println("Topping '"+arg+"' must start with + or -!");
				System.exit(1);
			}

			arg = arg.substring(1, namelen);

			Topping t = null;
			if(arg.toUpperCase().equals(arg)) {
				if(arg.equals("CHEESE")) {
					t = new Topping(null, Topping.CHEESE);
				} else if(arg.equals("MEAT")) {
					t = new Topping(null, Topping.MEAT);
				} else if(arg.equals("VEGGIE")) {
					t = new Topping(null, Topping.VEGGIE);
				} else {
					System.err.println("Topping type '"+arg+"' does not exist!");
					System.exit(1);
				}
			} else {
				t = p.getTopping(arg);
				if(t == null) {
					System.err.println("Topping '"+arg+"' does not exist!");
					System.exit(1);
				}
			}
			//System.out.println("Adding constraint " + negative + ", " + mandatory + ", " + t.name() + ", " + t.type());
			p.addConstraint(new ToppingConstraint(negative, mandatory, t));
		}

		Set toppings = p.toppings((new Integer(args[0])).intValue());
		Iterator i = toppings.iterator();
		while(i.hasNext()) {
			Topping t = (Topping)i.next();
			System.out.println(t);
		}
	}
}
